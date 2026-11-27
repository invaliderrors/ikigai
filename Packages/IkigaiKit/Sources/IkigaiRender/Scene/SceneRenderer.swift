import AppKit
import CoreImage
import Metal
import MetalKit

/// One image layer of a scene.
public struct SceneLayer {
    public enum Effect: Int32 { case none = 0, sway = 1, ripple = 2, wave = 3, shake = 4, scroll = 5 }

    public var texture: MTLTexture
    /// 0 stays still; 1 moves most with the mouse.
    public var depth: Float
    public var effect: Effect
    /// Red channel scales the effect per pixel; nil means everywhere.
    public var mask: MTLTexture?
    /// The part of the image (in 0...1 texture coordinates, origin top-left) that has visible pixels.
    /// Only this rectangle is drawn, so a mostly transparent layer costs only what it covers.
    public var bounds: CGRect
    /// A blurred copy of the layer drawn additively on top, pulsing gently; nil for no glow.
    public var glowTexture: MTLTexture?
    public var glow: Float

    public init(texture: MTLTexture, depth: Float, effect: Effect = .none, mask: MTLTexture? = nil,
                bounds: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), glowTexture: MTLTexture? = nil, glow: Float = 0) {
        self.texture = texture
        self.depth = depth
        self.effect = effect
        self.mask = mask
        self.bounds = bounds
        self.glowTexture = glowTexture
        self.glow = glow
    }

    /// A Gaussian-blurred copy, for depth of field and glow; done once at load, on the GPU through Core Image.
    public static func blurred(_ image: CGImage, radius: Double, using context: CIContext) throws -> CGImage {
        let input = CIImage(cgImage: image)
        let output = input.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: input.extent)
        guard let result = context.createCGImage(output, from: input.extent) else { throw CocoaError(.fileReadCorruptFile) }
        return result
    }

    /// A scene's brightness, contrast and saturation baked into a layer image once at load, since a grade
    /// never changes while a scene plays; 1 leaves the image as it is.
    public static func graded(_ image: CGImage, brightness: Double, contrast: Double, saturation: Double,
                              using context: CIContext) throws -> CGImage {
        guard brightness != 1 || contrast != 1 || saturation != 1 else { return image }
        let input = CIImage(cgImage: image)
        let b = CGFloat(brightness)
        let output = input
            .applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: b, y: 0, z: 0, w: 0),
                                                          "inputGVector": CIVector(x: 0, y: b, z: 0, w: 0),
                                                          "inputBVector": CIVector(x: 0, y: 0, z: b, w: 0)])
            .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: contrast, kCIInputSaturationKey: saturation])
        guard let result = context.createCGImage(output, from: input.extent) else { throw CocoaError(.fileReadCorruptFile) }
        return result
    }

    /// The rectangle of an image with any visible pixels, padded so effects that move pixels
    /// (sway, ripple) aren't clipped. Measured once at load on a small copy of the alpha channel.
    public static func visibleBounds(of image: CGImage, padding: CGFloat = 0.02) -> CGRect {
        let (w, h) = (256, 160)
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue),
              let data = context.data?.assumingMemoryBound(to: UInt8.self)
        else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var (minX, minY, maxX, maxY) = (w, h, -1, -1)
        for y in 0..<h { for x in 0..<w where data[y * w + x] > 2 {  // memory rows run top to bottom
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        } }
        guard maxX >= 0 else { return .zero }
        let rect = CGRect(x: CGFloat(minX) / CGFloat(w), y: CGFloat(minY) / CGFloat(h),
                          width: CGFloat(maxX - minX + 1) / CGFloat(w), height: CGFloat(maxY - minY + 1) / CGFloat(h))
        return rect.insetBy(dx: -padding, dy: -padding).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}

/// Draws a layered scene: image layers with masked effects and mouse parallax, then GPU particles.
/// Phase 2 spike: the smallest renderer that exercises the real costs.
@MainActor public final class SceneRenderer: NSObject, MTKViewDelegate {
    public let device: MTLDevice
    public var layers: [SceneLayer]
    public var particleCount: Int
    /// 0 snow, 1 rain, 2 dust, 3 petals, 4 embers.
    public var particleStyle: Int32 = 0
    /// Called on a Metal completion thread with each frame's GPU time in seconds.
    public var onFrameCompleted: (@Sendable (_ gpuSeconds: Double) -> Void)?

    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let glowPipeline: MTLRenderPipelineState
    private let particlePipeline: MTLRenderPipelineState
    private let blankMask: MTLTexture
    private let start = CACurrentMediaTime()
    private var parallax = SIMD2<Float>(0, 0)

    // Field order and types mirror the structs in SceneShaders.
    private struct LayerUniforms {
        var bounds: SIMD4<Float>, parallax: SIMD2<Float>, time: Float, depth: Float, overscan: Float, effect: Int32, glow: Float
    }
    private struct ParticleUniforms {
        var parallax: SIMD2<Float>, time: Float, aspect: Float, size: Float, style: Int32
    }

    public init(device: MTLDevice, layers: [SceneLayer], particleCount: Int) throws {
        guard let queue = device.makeCommandQueue() else { throw CocoaError(.featureUnsupported) }
        self.device = device
        self.queue = queue
        self.layers = layers
        self.particleCount = particleCount

        let library = try device.makeLibrary(source: SceneShaders.source, options: nil)
        func pipeline(_ vertex: String, _ fragment: String, additive: Bool = false) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: vertex)
            descriptor.fragmentFunction = library.makeFunction(name: fragment)
            let color = descriptor.colorAttachments[0]!
            color.pixelFormat = .bgra8Unorm
            color.isBlendingEnabled = true  // premultiplied alpha over, or light added on top
            color.sourceRGBBlendFactor = .one
            color.sourceAlphaBlendFactor = .one
            color.destinationRGBBlendFactor = additive ? .one : .oneMinusSourceAlpha
            color.destinationAlphaBlendFactor = additive ? .one : .oneMinusSourceAlpha
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }
        self.pipeline = try pipeline("layer_vertex", "layer_fragment")
        self.glowPipeline = try pipeline("layer_vertex", "glow_fragment", additive: true)
        self.particlePipeline = try pipeline("particle_vertex", "particle_fragment")

        let white = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 1, height: 1, mipmapped: false)
        guard let blank = device.makeTexture(descriptor: white) else { throw CocoaError(.featureUnsupported) }
        var one: UInt8 = 255
        blank.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &one, bytesPerRow: 1)
        self.blankMask = blank
        super.init()
    }

    /// Sets up a view for this renderer: 30 fps, no continuous redraw beyond that, black under the scene.
    public func attach(to view: MTKView, fps: Int = 30) {
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.preferredFramesPerSecond = fps
        view.enableSetNeedsDisplay = false
        view.delegate = self
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        updateParallax(for: view)
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let buffer = queue.makeCommandBuffer(), let encoder = buffer.makeRenderCommandEncoder(descriptor: pass)
        else { return }
        let time = Float(CACurrentMediaTime() - start)

        var current: MTLRenderPipelineState?  // switch state only when it changes
        for layer in layers where !layer.bounds.isEmpty {
            let b = layer.bounds
            var uniforms = LayerUniforms(bounds: SIMD4(Float(b.minX), Float(b.minY), Float(b.maxX), Float(b.maxY)),
                                         parallax: parallax, time: time, depth: layer.depth,
                                         overscan: 1 + 0.03 * layer.depth, effect: layer.effect.rawValue, glow: layer.glow)
            if current !== pipeline { encoder.setRenderPipelineState(pipeline); current = pipeline }
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<LayerUniforms>.stride, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LayerUniforms>.stride, index: 0)
            encoder.setFragmentTexture(layer.texture, index: 0)
            encoder.setFragmentTexture(layer.mask ?? blankMask, index: 1)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

            if let glowTexture = layer.glowTexture, layer.glow > 0 {
                // The bloom spreads past the layer's pixels, so its quad is wider than the layer's.
                let g = b.insetBy(dx: -0.08, dy: -0.08).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
                uniforms.bounds = SIMD4(Float(g.minX), Float(g.minY), Float(g.maxX), Float(g.maxY))
                encoder.setRenderPipelineState(glowPipeline); current = glowPipeline
                encoder.setVertexBytes(&uniforms, length: MemoryLayout<LayerUniforms>.stride, index: 0)
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LayerUniforms>.stride, index: 0)
                encoder.setFragmentTexture(glowTexture, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
        }

        if particleCount > 0 {
            let size = view.drawableSize
            var uniforms = ParticleUniforms(parallax: parallax, time: time,
                                            aspect: Float(size.width / max(size.height, 1)), size: 0.006, style: particleStyle)
            encoder.setRenderPipelineState(particlePipeline)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<ParticleUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: particleCount)
        }
        encoder.endEncoding()

        if let report = onFrameCompleted {
            buffer.addCompletedHandler { buffer in report(buffer.gpuEndTime - buffer.gpuStartTime) }
        }
        buffer.present(drawable)
        buffer.commit()
    }

    /// Eases toward the mouse's position on this view's screen; no permissions needed.
    private func updateParallax(for view: MTKView) {
        guard let frame = view.window?.screen?.frame else { return }
        let mouse = NSEvent.mouseLocation
        let target = SIMD2<Float>(Float(max(-1, min(1, (mouse.x - frame.midX) / (frame.width / 2)))),
                                  Float(max(-1, min(1, (mouse.y - frame.midY) / (frame.height / 2)))))
        parallax += (target - parallax) * 0.08
    }
}

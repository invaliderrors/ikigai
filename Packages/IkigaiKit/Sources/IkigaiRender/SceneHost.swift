import AppKit
import CoreImage
import IkigaiCore
import ImageIO
import MetalKit
import OSLog

/// Plays a scene wallpaper with the Metal scene renderer. Starts paused; the desktop decides when it plays.
@MainActor public final class SceneHost: WallpaperHost {
    public var view: NSView { metalView }
    private let metalView = MTKView()
    private let renderer: SceneRenderer

    /// Nil when the scene can't be loaded or Metal isn't available; the desktop then shows nothing there.
    // shortcut: decodes the layer images on the main thread when a scene is shown (a few hundred ms for large
    // scenes) and each screen loads its own copy; move to a shared async texture cache when scenes get bigger.
    public init?(entry: URL, package: URL) {
        let log = Logger(subsystem: "com.invaliderrors.ikigai", category: "scene")
        do {
            guard let device = MTLCreateSystemDefaultDevice() else { throw CocoaError(.featureUnsupported) }
            let scene = try SceneDocument.load(entry: entry, package: package)
            let loader = MTKTextureLoader(device: device)
            let images = CIContext(mtlDevice: device)
            func texture(_ image: CGImage) throws -> MTLTexture { try loader.newTexture(cgImage: image, options: [.SRGB: false]) }
            // Blur and glow are made once here, so they cost nothing per frame.
            func blurred(_ image: CGImage, radius: Double) throws -> CGImage {
                try SceneLayer.blurred(image, radius: radius, using: images)
            }
            let layers = try scene.layers.map { layer in
                var image = try Self.cgImage(at: layer.image)
                image = try SceneLayer.graded(image, brightness: scene.grade.brightness, contrast: scene.grade.contrast,
                                              saturation: scene.grade.saturation, using: images)
                if layer.blur > 0 { image = try blurred(image, radius: layer.blur * 30) }
                var bounds = SceneLayer.visibleBounds(of: image)
                if layer.effect == .scroll { bounds = CGRect(x: 0, y: bounds.minY, width: 1, height: bounds.height) }  // content wraps sideways
                return SceneLayer(texture: try texture(image), depth: Float(layer.depth), effect: SceneLayer.Effect(layer.effect),
                                  mask: try layer.mask.map { try texture(try Self.cgImage(at: $0)) }, bounds: bounds,
                                  glowTexture: layer.glow > 0 ? try texture(try blurred(image, radius: 40)) : nil, glow: Float(layer.glow))
            }
            renderer = try SceneRenderer(device: device, layers: layers, particleCount: scene.particles)
            renderer.particleStyle = Int32(SceneDocument.ParticleStyle.allCases.firstIndex(of: scene.particleStyle) ?? 0)
        } catch {
            log.error("Scene not loaded: \(error)")
            return nil
        }
        renderer.attach(to: metalView)
        metalView.isPaused = true
    }

    public func setPlaying(_ playing: Bool) {
        metalView.isPaused = !playing
    }

    static func cgImage(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw CocoaError(.fileReadCorruptFile) }
        return image
    }
}

extension SceneLayer.Effect {
    init(_ effect: SceneDocument.Effect) {
        switch effect {
        case .none: self = .none
        case .sway: self = .sway
        case .ripple: self = .ripple
        case .wave: self = .wave
        case .shake: self = .shake
        case .scroll: self = .scroll
        }
    }
}

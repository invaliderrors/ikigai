import AppKit
import CoreImage
import IkigaiCore
import ImageIO
import MetalKit
import OSLog

/// Plays a scene wallpaper with the Metal scene renderer. Starts paused; the desktop (or the Studio) decides when it plays.
@MainActor public final class SceneHost: WallpaperHost {
    public var view: NSView { metalView }
    private let metalView = MTKView()
    private let renderer: SceneRenderer
    /// What the loaded textures were made from; a change here needs a rebuild, anything else applies live.
    private let textureKey: [String]

    /// Nil when the scene can't be loaded or Metal isn't available; the desktop then shows nothing there.
    public convenience init?(entry: URL, package: URL) {
        guard let scene = try? SceneDocument.load(entry: entry, package: package) else {
            Logger(subsystem: "com.invaliderrors.ikigai", category: "scene").error("Scene not loaded: \(entry.path)")
            return nil
        }
        self.init(scene: scene)
    }

    // shortcut: decodes the layer images on the main thread when a scene is shown (a few hundred ms for large
    // scenes) and each screen loads its own copy; move to a shared async texture cache when scenes get bigger.
    public init?(scene: SceneDocument.Resolved) {
        do {
            guard let device = MTLCreateSystemDefaultDevice() else { throw CocoaError(.featureUnsupported) }
            let loader = MTKTextureLoader(device: device)
            let images = CIContext(mtlDevice: device)
            func texture(_ image: CGImage) throws -> MTLTexture { try loader.newTexture(cgImage: image, options: [.SRGB: false]) }
            // Blur, glow and the grade are made once here, so they cost nothing per frame.
            let layers = try scene.layers.map { layer in
                var image = try Self.cgImage(at: layer.image)
                image = try SceneLayer.graded(image, brightness: scene.grade.brightness, contrast: scene.grade.contrast,
                                              saturation: scene.grade.saturation, using: images)
                if layer.blur > 0 { image = try SceneLayer.blurred(image, radius: layer.blur * 30, using: images) }
                var bounds = SceneLayer.visibleBounds(of: image)
                if layer.effect == .scroll { bounds = CGRect(x: 0, y: bounds.minY, width: 1, height: bounds.height) }  // content wraps sideways
                return SceneLayer(texture: try texture(image), depth: Float(layer.depth), effect: SceneLayer.Effect(layer.effect),
                                  mask: try layer.mask.map { try texture(try Self.cgImage(at: $0)) }, bounds: bounds,
                                  glowTexture: layer.glow > 0 ? try texture(try SceneLayer.blurred(image, radius: 40, using: images)) : nil,
                                  glow: Float(layer.glow))
            }
            renderer = try SceneRenderer(device: device, layers: layers, particleCount: scene.particles)
        } catch {
            Logger(subsystem: "com.invaliderrors.ikigai", category: "scene").error("Scene not loaded: \(error)")
            return nil
        }
        textureKey = Self.textureKey(scene)
        renderer.particleStyle = Self.styleIndex(scene.particleStyle)
        renderer.attach(to: metalView)
        metalView.isPaused = true
    }

    public func setPlaying(_ playing: Bool) {
        metalView.isPaused = !playing
    }

    /// Applies an edited scene without reloading: depth, effect, glow strength and particles change in place.
    /// Returns false when the edit needs new textures (images, masks, blur, grade, glow turned on or off,
    /// scroll's full-width bounds); the caller then builds a new host.
    public func applyLive(_ scene: SceneDocument.Resolved) -> Bool {
        guard Self.textureKey(scene) == textureKey else { return false }
        for (index, layer) in scene.layers.enumerated() {
            renderer.layers[index].depth = Float(layer.depth)
            renderer.layers[index].effect = SceneLayer.Effect(layer.effect)
            renderer.layers[index].glow = Float(layer.glow)
        }
        renderer.particleCount = scene.particles
        renderer.particleStyle = Self.styleIndex(scene.particleStyle)
        return true
    }

    private static func textureKey(_ scene: SceneDocument.Resolved) -> [String] {
        let g = scene.grade
        return ["\(g.brightness) \(g.contrast) \(g.saturation)"] + scene.layers.map {
            "\($0.image.path)|\($0.mask?.path ?? "")|\($0.blur)|\($0.glow > 0)|\($0.effect == .scroll)"
        }
    }

    private static func styleIndex(_ style: SceneDocument.ParticleStyle) -> Int32 {
        Int32(SceneDocument.ParticleStyle.allCases.firstIndex(of: style) ?? 0)
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

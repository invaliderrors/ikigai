import AppKit
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
            let layers = try scene.layers.map { layer in
                let image = try Self.cgImage(at: layer.image)
                return SceneLayer(texture: try loader.newTexture(cgImage: image, options: [.SRGB: false]),
                                  depth: Float(layer.depth), effect: SceneLayer.Effect(layer.effect),
                                  mask: try layer.mask.map { try loader.newTexture(cgImage: try Self.cgImage(at: $0), options: [.SRGB: false]) },
                                  bounds: SceneLayer.visibleBounds(of: image))
            }
            renderer = try SceneRenderer(device: device, layers: layers, particleCount: scene.particles)
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
        }
    }
}

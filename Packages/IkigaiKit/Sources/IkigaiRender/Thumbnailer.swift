import AppKit
import AVFoundation
import IkigaiCore
import ImageIO
import UniformTypeIdentifiers

/// Writes a wallpaper's `preview.jpg`, the still the Library shows instead of playing every tile.
@MainActor public enum Thumbnailer {
    public static let size = CGSize(width: 800, height: 500)

    public enum Failure: Error { case pageDidNotLoad, noImage }

    public static func makePreview(for wallpaper: InstalledWallpaper) async throws {
        switch wallpaper.manifest.kind {
        case .video: try await makeVideoPreview(for: wallpaper)
        case .web: try await makeWebPreview(for: wallpaper)
        case .scene: try makeScenePreview(for: wallpaper)
        }
    }

    /// The layers stacked as they first appear, without effects or particles: a CoreGraphics composite, no GPU.
    private static func makeScenePreview(for wallpaper: InstalledWallpaper) throws {
        let scene = try SceneDocument.load(entry: wallpaper.entryURL, package: wallpaper.packageURL)
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw Failure.noImage }
        context.interpolationQuality = .high
        for layer in scene.layers {
            let image = try SceneHost.cgImage(at: layer.image)
            let scale = max(size.width / CGFloat(image.width), size.height / CGFloat(image.height))
            let drawn = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
            context.draw(image, in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2,
                                           width: drawn.width, height: drawn.height))
        }
        guard let image = context.makeImage() else { throw Failure.noImage }
        try writeJPEG(image, to: wallpaper.previewURL)
    }

    /// A frame from one second in.
    private static func makeVideoPreview(for wallpaper: InstalledWallpaper) async throws {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: wallpaper.entryURL))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size
        let (image, _) = try await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600))
        try writeJPEG(image, to: wallpaper.previewURL)
    }

    /// Renders the page off-screen in the same sandbox the desktop uses, lets it draw for a second, and snapshots it.
    private static func makeWebPreview(for wallpaper: InstalledWallpaper) async throws {
        let host = WebHost(page: wallpaper.entryURL, package: wallpaper.packageURL)
        // On screen but practically invisible: an off-screen or covered window counts as occluded, and WebKit
        // then stops requestAnimationFrame, so animated pages would snapshot as their empty background.
        let origin = NSScreen.main?.frame.origin ?? .zero
        let window = NSWindow(contentRect: CGRect(origin: origin, size: CGSize(width: 1440, height: 900)),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.alphaValue = 0.01
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        window.contentView = host.view
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        guard await host.waitUntilLoaded(timeout: .seconds(8)) else { throw Failure.pageDidNotLoad }
        try await Task.sleep(for: .seconds(1))
        guard let image = await host.snapshot()?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw Failure.noImage }
        try writeJPEG(scaled(image), to: wallpaper.previewURL)
    }

    /// Aspect-fill into the preview size.
    private static func scaled(_ image: CGImage) -> CGImage {
        let scale = max(size.width / CGFloat(image.width), size.height / CGFloat(image.height))
        let drawn = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2,
                                       width: drawn.width, height: drawn.height))
        return context.makeImage() ?? image
    }

    static func writeJPEG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}

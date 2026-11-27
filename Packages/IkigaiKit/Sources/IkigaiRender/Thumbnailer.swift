import AVFoundation
import IkigaiCore
import ImageIO
import UniformTypeIdentifiers

/// Writes a wallpaper's `preview.jpg`, the still the Library shows instead of playing every tile.
public enum Thumbnailer {
    public static let size = CGSize(width: 800, height: 500)

    /// Videos get a frame from one second in. Web wallpapers have no preview yet; the Library shows their kind instead.
    public static func makePreview(for wallpaper: InstalledWallpaper) async throws {
        guard wallpaper.manifest.kind == .video else { return }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: wallpaper.entryURL))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size
        let (image, _) = try await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600))
        try writeJPEG(image, to: wallpaper.previewURL)
    }

    static func writeJPEG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}

import CoreImage
import Foundation
import IkigaiCore
import Vision

/// Turns one picture into a parallax scene: Vision lifts the subject out, the background behind it is
/// filled from its surroundings so parallax never reveals a hole, and a look adds motion and colour.
public enum PictureSceneMaker {
    /// The longest side layers are scaled to; enough for a 4K screen and far below Metal's texture limit.
    public static let maxSide: CGFloat = 3840

    public struct Prepared: Sendable {
        /// A temporary folder holding `background.png` and, when a subject was found, `subject.png`.
        public let folder: URL
        public let hasSubject: Bool
        public let title: String
    }

    public enum Failure: Error { case unreadableImage }

    public enum Look: String, CaseIterable, Sendable, Identifiable {
        case gentle, goldenHour, nightRain, petals
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .gentle: "Gentle Parallax"
            case .goldenHour: "Golden Hour"
            case .nightRain: "Night Rain"
            case .petals: "Petal Drift"
            }
        }
    }

    /// Slow work (Vision and Core Image on a large picture): call it off the main thread.
    public static func prepare(_ source: URL) throws -> Prepared {
        guard let loaded = CIImage(contentsOf: source, options: [.applyOrientationProperty: true]) else { throw Failure.unreadableImage }
        let scale = min(1, maxSide / max(loaded.extent.width, loaded.extent.height))
        let original = loaded.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
            .cropped(to: CGRect(origin: .zero, size: CGSize(width: (loaded.extent.width * scale).rounded(.down),
                                                             height: (loaded.extent.height * scale).rounded(.down))))
        let context = CIContext()
        guard let cgImage = context.createCGImage(original, from: original.extent) else { throw Failure.unreadableImage }

        let folder = FileManager.default.temporaryDirectory.appending(path: "ikigai-picture-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let title = source.deletingPathExtension().lastPathComponent
        func write(_ image: CIImage, _ name: String) throws {
            try context.writePNGRepresentation(of: image, to: folder.appending(path: name), format: .RGBA8,
                                               colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        }

        guard let subject = try liftSubject(from: cgImage) else {
            try write(original, "background.png")
            return Prepared(folder: folder, hasSubject: false, title: title)
        }
        try write(subject, "subject.png")
        try write(fillBehind(subject: subject, in: original), "background.png")
        return Prepared(folder: folder, hasSubject: true, title: title)
    }

    /// The subject with a soft alpha edge, at full size, or nil when Vision finds no clear subject.
    static func liftSubject(from image: CGImage) throws -> CIImage? {
        let handler = VNImageRequestHandler(cgImage: image)
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
        let masked = try observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: false)
        return CIImage(cvPixelBuffer: masked)
    }

    /// The background with the subject's area filled from its surroundings (normalized convolution at low
    /// resolution: blur the visible pixels and their coverage, then divide), so parallax never shows a hole.
    static func fillBehind(subject: CIImage, in original: CIImage) -> CIImage {
        let extent = original.extent
        // White where the subject is, grown a little so its edge doesn't leave a halo of its own colours.
        let subjectMask = subject.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ]).applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: 10]).cropped(to: extent)
        let keep = subjectMask.applyingFilter("CIColorInvert")
        let visible = original.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.clear.cropped(to: extent), kCIInputMaskImageKey: keep,
        ])
        // Small, so one blur reaches across even a large subject; the result is soft by nature anyway.
        let small: CGFloat = 1.0 / 8
        // A plain downscale is enough: the fill is blurred heavily straight after.
        let filled = visible
            .transformed(by: CGAffineTransform(scaleX: small, y: small))
            .clampedToExtent().applyingGaussianBlur(sigma: 24)
            .transformed(by: CGAffineTransform(scaleX: 1 / small, y: 1 / small))
            // Setting alpha to 1 does the dividing: Core Image un-premultiplies before a colour matrix, so the
            // blurred colour is divided by the blurred coverage exactly once. (An explicit CIUnpremultiply first
            // divided twice and washed the fill out to white; CISettingAlphaOneInExtent returns an empty image here.)
            .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                                                          "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)])
            .cropped(to: extent)
        // Cropped again: some filters in the chain report an unbounded extent, which can't be written out.
        return filled.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: original, kCIInputMaskImageKey: subjectMask])
            .cropped(to: extent)
    }

    /// The scene for a look. The subject sits in front with more parallax than the softened background.
    public static func scene(_ look: Look, hasSubject: Bool) -> SceneDocument {
        var layers = [SceneDocument.Layer(image: "background.png", depth: hasSubject ? 0.15 : 0.35, blur: hasSubject ? 0.12 : 0)]
        if hasSubject { layers.append(SceneDocument.Layer(image: "subject.png", depth: 0.7)) }
        switch look {
        case .gentle:
            return SceneDocument(layers: layers)
        case .goldenHour:
            return SceneDocument(layers: layers, particles: 700, particleStyle: .dust,
                                 grade: .init(brightness: 1.06, contrast: 1.04, saturation: 1.15))
        case .nightRain:
            return SceneDocument(layers: layers, particles: 1400, particleStyle: .rain,
                                 grade: .init(brightness: 0.72, contrast: 1.1, saturation: 0.75))
        case .petals:
            return SceneDocument(layers: layers, particles: 450, particleStyle: .petals,
                                 grade: .init(brightness: 1.03, contrast: 1, saturation: 1.08))
        }
    }
}

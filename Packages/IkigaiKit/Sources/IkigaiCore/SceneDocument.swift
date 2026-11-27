import Foundation

/// A scene wallpaper's `scene.json`: image layers back to front, each with depth, an optional masked
/// effect, blur and glow, plus a colour grade and particles. Paths are relative to the scene file's
/// folder and must stay inside the package. Versioned on its own, so the manifest format doesn't
/// change when scenes grow.
///
/// Version 2 added wave, shake and scroll, per-layer blur and glow, the grade, and particle styles.
/// Version 1 files read unchanged.
public struct SceneDocument: Codable, Hashable, Sendable {
    public static let currentVersion = 2
    public static let maxLayers = 32
    public static let maxParticles = 5000

    public enum Effect: String, Codable, Sendable, CaseIterable {
        case none, sway, ripple, wave, shake, scroll
    }

    public enum ParticleStyle: String, Codable, Sendable, CaseIterable {
        case snow, rain, dust, petals, embers
    }

    public struct Layer: Codable, Hashable, Sendable {
        public var image: String
        /// 0 stays still; 1 moves most with the mouse.
        public var depth: Double
        public var effect: Effect
        /// Greyscale image; white is full effect, black none.
        public var mask: String?
        /// 0...1, applied once when the scene loads (depth of field costs nothing per frame).
        public var blur: Double
        /// 0...1, a soft pulsing bloom drawn over the layer.
        public var glow: Double

        public init(image: String, depth: Double = 0, effect: Effect = .none, mask: String? = nil, blur: Double = 0, glow: Double = 0) {
            self.image = image
            self.depth = depth
            self.effect = effect
            self.mask = mask
            self.blur = blur
            self.glow = glow
        }

        // Everything but `image` is optional in the file, so hand-written scenes stay short.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            image = try c.decode(String.self, forKey: .image)
            depth = try c.decodeIfPresent(Double.self, forKey: .depth) ?? 0
            effect = try c.decodeIfPresent(Effect.self, forKey: .effect) ?? .none
            mask = try c.decodeIfPresent(String.self, forKey: .mask)
            blur = try c.decodeIfPresent(Double.self, forKey: .blur) ?? 0
            glow = try c.decodeIfPresent(Double.self, forKey: .glow) ?? 0
        }
    }

    /// A whole-scene colour grade. 1 leaves the picture as it is.
    public struct Grade: Codable, Hashable, Sendable {
        public var brightness: Double
        public var contrast: Double
        public var saturation: Double

        public static let neutral = Grade(brightness: 1, contrast: 1, saturation: 1)

        public init(brightness: Double = 1, contrast: Double = 1, saturation: Double = 1) {
            self.brightness = brightness
            self.contrast = contrast
            self.saturation = saturation
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            brightness = try c.decodeIfPresent(Double.self, forKey: .brightness) ?? 1
            contrast = try c.decodeIfPresent(Double.self, forKey: .contrast) ?? 1
            saturation = try c.decodeIfPresent(Double.self, forKey: .saturation) ?? 1
        }
    }

    public var version: Int
    public var layers: [Layer]
    public var particles: Int
    public var particleStyle: ParticleStyle
    public var grade: Grade

    public init(layers: [Layer], particles: Int = 0, particleStyle: ParticleStyle = .snow, grade: Grade = .neutral) {
        self.version = Self.currentVersion
        self.layers = layers
        self.particles = particles
        self.particleStyle = particleStyle
        self.grade = grade
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        layers = try c.decode([Layer].self, forKey: .layers)
        particles = try c.decodeIfPresent(Int.self, forKey: .particles) ?? 0
        particleStyle = try c.decodeIfPresent(ParticleStyle.self, forKey: .particleStyle) ?? .snow
        grade = try c.decodeIfPresent(Grade.self, forKey: .grade) ?? .neutral
    }

    public enum Failure: Error, Equatable {
        case unreadable
        case newerVersion(found: Int, supported: Int)
        case noLayers
        case tooManyLayers(Int)
        case missingFile(String)
    }

    /// A scene whose file references are resolved and whose values are clamped to safe ranges.
    public struct Resolved: Sendable {
        public struct Layer: Sendable {
            public var image: URL
            public var mask: URL?
            public var depth: Double
            public var effect: Effect
            public var blur: Double
            public var glow: Double
        }
        public var layers: [Layer]
        public var particles: Int
        public var particleStyle: ParticleStyle
        public var grade: Grade
    }

    /// Reads and validates a scene. It may come from a stranger: every referenced file must exist inside
    /// the package, every number is clamped to a sane range, and a newer version is refused.
    public static func load(entry: URL, package: URL) throws -> Resolved {
        guard let data = try? Data(contentsOf: entry) else { throw Failure.unreadable }
        // Check the version before decoding the rest: a newer file may use effects this build doesn't know.
        struct Header: Decodable { var version: Int }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else { throw Failure.unreadable }
        guard header.version <= currentVersion else { throw Failure.newerVersion(found: header.version, supported: currentVersion) }
        guard let scene = try? JSONDecoder().decode(SceneDocument.self, from: data) else { throw Failure.unreadable }
        guard !scene.layers.isEmpty else { throw Failure.noLayers }
        guard scene.layers.count <= maxLayers else { throw Failure.tooManyLayers(scene.layers.count) }

        let folder = entry.deletingLastPathComponent()
        let root = package.standardizedFileURL.path + "/"
        func file(_ path: String) throws -> URL {
            // Relative to the scene's folder, but never outside the package.
            guard let url = PackagePath.resolve(path, in: folder), url.path.hasPrefix(root),
                  FileManager.default.fileExists(atPath: url.path) else { throw Failure.missingFile(path) }
            return url
        }
        func unit(_ value: Double) -> Double { value.isFinite ? min(max(value, 0), 1) : 0 }
        func grade(_ value: Double) -> Double { value.isFinite ? min(max(value, 0), 2) : 1 }

        let layers = try scene.layers.map { layer in
            Resolved.Layer(image: try file(layer.image), mask: try layer.mask.map(file), depth: unit(layer.depth),
                           effect: layer.effect, blur: unit(layer.blur), glow: unit(layer.glow))
        }
        return Resolved(layers: layers, particles: min(max(scene.particles, 0), maxParticles), particleStyle: scene.particleStyle,
                        grade: Grade(brightness: grade(scene.grade.brightness), contrast: grade(scene.grade.contrast),
                                     saturation: grade(scene.grade.saturation)))
    }
}

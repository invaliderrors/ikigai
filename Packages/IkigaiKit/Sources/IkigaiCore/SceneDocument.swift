import Foundation

/// A scene wallpaper's `scene.json`: image layers back to front, each with depth and an optional
/// masked effect, plus particles. Paths are relative to the scene file's folder and must stay inside
/// the package. Versioned on its own, so the manifest format doesn't change when scenes grow.
public struct SceneDocument: Codable, Hashable, Sendable {
    public static let currentVersion = 1
    public static let maxLayers = 32
    public static let maxParticles = 5000

    public enum Effect: String, Codable, Sendable, CaseIterable {
        case none, sway, ripple
    }

    public struct Layer: Codable, Hashable, Sendable {
        public var image: String
        /// 0 stays still; 1 moves most with the mouse.
        public var depth: Double
        public var effect: Effect
        /// Greyscale image; white is full effect, black none.
        public var mask: String?

        public init(image: String, depth: Double = 0, effect: Effect = .none, mask: String? = nil) {
            self.image = image
            self.depth = depth
            self.effect = effect
            self.mask = mask
        }

        // Fields beyond `image` are optional in the file, so hand-written scenes stay short.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            image = try c.decode(String.self, forKey: .image)
            depth = try c.decodeIfPresent(Double.self, forKey: .depth) ?? 0
            effect = try c.decodeIfPresent(Effect.self, forKey: .effect) ?? .none
            mask = try c.decodeIfPresent(String.self, forKey: .mask)
        }
    }

    public var version: Int
    public var layers: [Layer]
    public var particles: Int

    public init(layers: [Layer], particles: Int = 0) {
        self.version = Self.currentVersion
        self.layers = layers
        self.particles = particles
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        layers = try c.decode([Layer].self, forKey: .layers)
        particles = try c.decodeIfPresent(Int.self, forKey: .particles) ?? 0
    }

    public enum Failure: Error, Equatable {
        case unreadable
        case newerVersion(found: Int, supported: Int)
        case noLayers
        case tooManyLayers(Int)
        case missingFile(String)
    }

    /// A scene whose file references are resolved and checked.
    public struct Resolved: Sendable {
        public struct Layer: Sendable {
            public var image: URL
            public var mask: URL?
            public var depth: Double
            public var effect: Effect
        }
        public var layers: [Layer]
        public var particles: Int
    }

    /// Reads and validates a scene. It may come from a stranger: every referenced file must exist inside
    /// the package, depth is clamped to 0...1, particles to 0...maxParticles, and a newer version is refused.
    public static func load(entry: URL, package: URL) throws -> Resolved {
        guard let data = try? Data(contentsOf: entry), let scene = try? JSONDecoder().decode(SceneDocument.self, from: data) else {
            throw Failure.unreadable
        }
        guard scene.version <= currentVersion else { throw Failure.newerVersion(found: scene.version, supported: currentVersion) }
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
        let layers = try scene.layers.map { layer in
            Resolved.Layer(image: try file(layer.image), mask: try layer.mask.map(file),
                           depth: min(max(layer.depth, 0), 1), effect: layer.effect)
        }
        return Resolved(layers: layers, particles: min(max(scene.particles, 0), maxParticles))
    }
}

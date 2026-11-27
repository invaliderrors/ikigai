import Foundation

/// `manifest.json` at the root of every `.ikigai` package.
public struct WallpaperManifest: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case scene, video, web
    }

    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var id: UUID
    public var title: String
    public var kind: Kind
    /// Main file, relative to the package root (scene document, movie, or HTML page).
    public var entry: String
    public var tags: [String]

    public init(title: String, kind: Kind, entry: String, tags: [String] = [], id: UUID = UUID()) {
        self.formatVersion = Self.currentFormatVersion
        self.id = id
        self.title = title
        self.kind = kind
        self.entry = entry
        self.tags = tags
    }

    public enum DecodingFailure: Error, Equatable {
        case newerFormat(found: Int, supported: Int)
    }

    /// Decodes a manifest, refusing formats newer than this build understands.
    public static func decode(from data: Data) throws -> WallpaperManifest {
        let manifest = try JSONDecoder().decode(WallpaperManifest.self, from: data)
        guard manifest.formatVersion <= currentFormatVersion else {
            throw DecodingFailure.newerFormat(found: manifest.formatVersion, supported: currentFormatVersion)
        }
        return manifest
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

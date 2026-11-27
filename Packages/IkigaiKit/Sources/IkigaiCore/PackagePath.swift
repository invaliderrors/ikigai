import Foundation

public enum PackagePath {
    /// Resolves a path named inside a package. Returns nil when it would escape the package root
    /// (e.g. `../../.ssh/id_rsa`): packages come from strangers.
    public static func resolve(_ relativePath: String, in packageRoot: URL) -> URL? {
        let root = packageRoot.standardizedFileURL
        let url = root.appending(path: relativePath).standardizedFileURL
        return url.path.hasPrefix(root.path + "/") ? url : nil
    }
}

import Foundation

/// Use verified archive metadata rather than a search result's latest version.
enum ArchiveFilename {
    static func url(in directory: URL, audit: Audit, platform: String? = nil) -> URL {
        let name = component(audit.appName ?? audit.bundleID, fallback: "App", byteLimit: 100)
        let version = component(audit.version, fallback: "unknown-version", byteLimit: 40)
        let platform = component(platform ?? audit.platform ?? "ios", fallback: "ios", byteLimit: 24)
        let state = audit.encrypted == 0 ? "decrypted" : "partial"
        return directory.appendingPathComponent("\(name)-\(version)-\(platform)-\(state).ipa")
    }

    private static func component(_ value: String, fallback: String, byteLimit: Int) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ._-"))
        let cleaned = String(value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" })
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .-"))
        var result = ""
        for character in cleaned {
            guard result.utf8.count + String(character).utf8.count <= byteLimit else { break }
            result.append(character)
        }
        return result.isEmpty ? fallback : result
    }

    /// FileManager refuses an existing destination; neither archive is overwritten.
    static func finalize(_ provisional: URL, audit: Audit, platform: String? = nil) throws -> URL {
        let destination = url(in: provisional.deletingLastPathComponent(), audit: audit, platform: platform)
        try FileManager.default.moveItem(at: provisional, to: destination)
        return destination
    }
}

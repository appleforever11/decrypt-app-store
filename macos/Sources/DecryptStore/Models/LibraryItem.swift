import Foundation

struct LibraryItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    let bundleID: String
    let version: String
    var build: String?
    var platform: String
    let output: String
    var iconURL: URL?

    var platformLabel: String { Platform(rawValue: platform)?.title ?? (platform == "ios" ? "iOS" : platform) }
}

import Foundation

enum Platform: String, CaseIterable, Identifiable, Codable {
    case iphone, ipad, macos, watchos, visionos, appletv
    var id: String { rawValue }
    var title: String { ["iphone":"iPhone", "ipad":"iPad", "macos":"Mac", "watchos":"Apple Watch", "visionos":"Apple Vision", "appletv":"Apple TV"][rawValue]! }
    var symbol: String { ["iphone":"iphone", "ipad":"ipad", "macos":"desktopcomputer", "watchos":"applewatch", "visionos":"vision.pro", "appletv":"appletv"][rawValue]! }
}
struct StoreApp: Decodable, Identifiable, Hashable {
    let id: Int
    let bundleID: String
    let name: String
    let version: String
    let price: Double
    let platforms: [String]?
}
struct SearchResponse: Decodable { let apps: [StoreApp] }
struct VersionResponse: Decodable { let externalVersionIdentifiers: [String] }
struct Slice: Codable, Identifiable {
    var id: String { "\(path):\(offset)" }
    let path: String
    let offset: Int
    let architecture: String
    let cryptid: Int
}
struct Audit: Codable {
    var appName: String? = nil
    var platform: String? = nil
    let bundleID: String
    let version: String
    let slices: [Slice]
    let crcValid: Bool
    let inventoryMatches: Bool
    let identityMatches: Bool
    var encrypted: Int { slices.filter { $0.cryptid != 0 }.count }
    var summary: String { encrypted == 0 ? "All \(slices.count) slices clear" : "Partial • \(encrypted) of \(slices.count) slices still encrypted" }
}
struct Job: Identifiable, Codable {
    var id = UUID()
    var title: String
    var platform: String
    var status: String = "Queued"
    var detail: String = "Waiting to start"
    var source: String?
    var output: String?
    var audit: Audit?
    var progress: Double?
    var finished = false
}
struct Settings: Codable {
    var ipatool = "/opt/homebrew/bin/ipatool"
    var python = "/usr/bin/python3"
    var decryptor = ""
    var credential = ""
    var output = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].appendingPathComponent("Decrypt App Store").path
}
struct VersionMetadata: Decodable {
    let externalVersionID: String
    let displayVersion: String
    let releaseDate: String?
}
struct AppVersion: Identifiable {
    let id: String
    var displayVersion: String?
    var unavailable = false
    var label: String { displayVersion ?? (unavailable ? "Version unavailable" : "Resolving version…") }
}
struct ArtworkResponse: Decodable {
    struct Item: Decodable { let trackId: Int; let artworkUrl512: URL?; let artworkUrl100: URL? }
    let results: [Item]
}
struct ChartResponse: Decodable {
    struct Feed: Decodable { let title: String; let updated: String; let results: [PopularApp] }
    let feed: Feed
}
struct PopularApp: Decodable, Identifiable {
    let id: String
    let name: String
    let artistName: String
    let artworkUrl100: URL
}
struct LookupResponse: Decodable {
    struct Item: Decodable {
        let trackId: Int
        let bundleId: String
        let trackName: String
        let version: String
        let price: Double?
        let artworkUrl512: URL?
        var app: StoreApp { StoreApp(id: trackId, bundleID: bundleId, name: trackName, version: version, price: price ?? 0, platforms: nil) }
    }
    let results: [Item]
}

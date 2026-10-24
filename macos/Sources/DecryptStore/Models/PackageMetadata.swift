import Foundation

struct PackageMetadata: Decodable {
    let appName: String
    let bundleID: String
    let version: String
    let buildNumber: String
    let platform: String
}

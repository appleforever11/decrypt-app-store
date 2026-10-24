import XCTest
@testable import DecryptStore

final class LibraryDiscoveryTests: XCTestCase {
    func testRecoversOnlySuccessfulAppOwnedOutputs() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let success = root.appendingPathComponent(UUID().uuidString)
        try makeOutput(success, encrypted: false)
        try makeOutput(root.appendingPathComponent(UUID().uuidString), encrypted: true)
        try makeOutput(root.appendingPathComponent("Unrelated.app"), encrypted: false)
        let items = LibraryDiscovery.recover(from: root)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first.map { URL(fileURLWithPath: $0.output).resolvingSymlinksInPath().path }, success.appendingPathComponent("decrypted.ipa").resolvingSymlinksInPath().path)
        XCTAssertEqual(items.first?.bundleID, "com.example.app")
    }
    func testOriginalDownloadsAndMissingOutputsAreExcluded() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent(UUID().uuidString)
        try makeOutput(folder, encrypted: false)
        try FileManager.default.moveItem(at: folder.appendingPathComponent("decrypted.ipa"), to: folder.appendingPathComponent("original.ipa"))
        XCTAssertTrue(LibraryDiscovery.recover(from: root).isEmpty)
        XCTAssertTrue(LibraryDiscovery.recover(from: root.appendingPathComponent("missing")).isEmpty)
    }
    private func makeOutput(_ folder: URL, encrypted: Bool) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let audit = Audit(bundleID: "com.example.app", version: "1.0", slices: [Slice(path: "App", offset: 0, architecture: "arm64", cryptid: encrypted ? 1 : 0)], crcValid: true, inventoryMatches: true, identityMatches: true)
        try JSONEncoder().encode(audit).write(to: folder.appendingPathComponent("validation.json"))
        try Data("fixture".utf8).write(to: folder.appendingPathComponent(encrypted ? "Example-1.0-ios-partial.ipa" : "decrypted.ipa"))
    }
}

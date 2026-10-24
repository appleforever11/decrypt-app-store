import XCTest
@testable import DecryptStore

final class ArchiveFilenameTests: XCTestCase {
    private func audit(name: String? = "Microsoft Teams", version: String = "8.11.0", platform: String? = "visionos", encrypted: Bool = false) -> Audit {
        Audit(appName: name, platform: platform, bundleID: "com.microsoft.skype.teams", version: version,
              slices: [Slice(path: "Payload/Teams.app/Teams", offset: 0, architecture: "arm64", cryptid: encrypted ? 1 : 0)],
              crcValid: true, inventoryMatches: true, identityMatches: true)
    }
    func testNameUsesVerifiedVersionAndPlatform() {
        XCTAssertEqual(ArchiveFilename.url(in: URL(fileURLWithPath: "/tmp"), audit: audit()).lastPathComponent,
                       "Microsoft Teams-8.11.0-visionos-decrypted.ipa")
    }
    func testPartialArchiveIsExplicit() {
        XCTAssertTrue(ArchiveFilename.url(in: URL(fileURLWithPath: "/tmp"), audit: audit(encrypted: true)).lastPathComponent.hasSuffix("-partial.ipa"))
    }
    func testPlatformSelectionIsPreserved() {
        XCTAssertTrue(ArchiveFilename.url(in: URL(fileURLWithPath: "/tmp"), audit: audit(platform: "ios"), platform: "ipad").lastPathComponent.contains("-ipad-"))
    }
    func testUnsafeNamesRemainOneBoundedComponent() {
        let result = ArchiveFilename.url(in: URL(fileURLWithPath: "/tmp"), audit: audit(name: "../Test/App: \n" + String(repeating: "🎮界", count: 100)))
        XCTAssertEqual(result.deletingLastPathComponent().path, "/tmp")
        XCTAssertLessThan(result.lastPathComponent.utf8.count, 255)
        XCTAssertFalse(result.lastPathComponent.hasPrefix("."))
    }
    func testLegacyAuditFallsBackToBundleID() throws {
        let data = Data(#"{"bundleID":"com.example.app","version":"1.2","slices":[],"crcValid":true,"inventoryMatches":true,"identityMatches":true}"#.utf8)
        let oldAudit = try JSONDecoder().decode(Audit.self, from: data)
        XCTAssertEqual(ArchiveFilename.url(in: URL(fileURLWithPath: "/tmp"), audit: oldAudit).lastPathComponent,
                       "com.example.app-1.2-ios-decrypted.ipa")
    }
    func testFinalizePreservesBytesAndRefusesCollision() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let provisional = directory.appendingPathComponent(".decrypting.ipa")
        let bytes = Data("archive-content".utf8)
        try bytes.write(to: provisional)
        let named = try ArchiveFilename.finalize(provisional, audit: audit())
        XCTAssertEqual(try Data(contentsOf: named), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: provisional.path))
        try Data("another-archive".utf8).write(to: provisional)
        XCTAssertThrowsError(try ArchiveFilename.finalize(provisional, audit: audit()))
        XCTAssertEqual(try Data(contentsOf: named), bytes)
        XCTAssertEqual(try Data(contentsOf: provisional), Data("another-archive".utf8))
    }
}

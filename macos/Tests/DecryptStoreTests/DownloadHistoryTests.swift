import XCTest
@testable import DecryptStore

@MainActor final class DownloadHistoryTests: XCTestCase {
    func testClearHistoryPersistsAndPreservesDownloadedFiles() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("Example.ipa")
        try Data("preserved archive".utf8).write(to: output)
        let state = directory.appendingPathComponent("state")
        try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
        let audit = Audit(bundleID: "com.example.app", version: "1.0", slices: [], crcValid: true, inventoryMatches: true, identityMatches: true)
        let job = Job(title: "Example", platform: "iPhone", status: "Validated", output: output.path, audit: audit, finished: true)
        try JSONEncoder().encode([job]).write(to: state.appendingPathComponent("library.json"))
        let store = Store(storageURL: state)
        XCTAssertEqual(store.libraryItems.count, 1)
        store.clearDownloads()
        XCTAssertEqual(store.libraryItems.count, 1)
        XCTAssertEqual(Store(storageURL: state).libraryItems.count, 1)
        XCTAssertTrue(store.jobs.isEmpty)
        XCTAssertTrue(Store(storageURL: directory.appendingPathComponent("state")).jobs.isEmpty)
        XCTAssertEqual(try Data(contentsOf: output), Data("preserved archive".utf8))
    }
    func testClearRemovesQueuedJobsBeforeTheyRun() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = Store(storageURL: directory.appendingPathComponent("state"))
        store.settings.output = directory.appendingPathComponent("outputs").path
        store.enqueueLocal(directory.appendingPathComponent("One.ipa"))
        store.enqueueLocal(directory.appendingPathComponent("Two.ipa"))
        store.clearDownloads()
        await Task.yield()
        XCTAssertTrue(store.jobs.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.settings.output))
    }
    func testLegacyDownloadHistoryStillDecodes() async throws {
        let old = Data(#"{"id":"982A262D-2574-4B86-9597-EFEC96A596C6","title":"Example","platform":"iPhone","status":"Validated","detail":"Clear","finished":true}"#.utf8)
        let job = try JSONDecoder().decode(Job.self, from: old)
        XCTAssertEqual(job.title, "Example")
        XCTAssertNil(job.iconURL)
        XCTAssertNil(job.buildNumber)
    }
}

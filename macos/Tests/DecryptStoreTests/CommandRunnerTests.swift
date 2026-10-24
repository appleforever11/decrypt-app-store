import XCTest
@testable import DecryptStore

final class CommandRunnerTests: XCTestCase {
    func testDrainsBothPipesWithoutDeadlock() async throws {
        let runner = CommandRunner()
        let data = try await runner.run("/usr/bin/python3", ["-c", "import sys; sys.stderr.write('e'*1000000); sys.stdout.write('x'*1000000)"])
        XCTAssertEqual(data.count, 1_000_000)
    }
    func testCancellationBeforeLaunch() async {
        let runner = CommandRunner(); runner.cancel()
        do { _ = try await runner.run("/usr/bin/true", []); XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
    func testCancellationOfRunningProcess() async {
        let runner = CommandRunner()
        let task = Task { try await runner.run("/usr/bin/python3", ["-c", "import time; time.sleep(30)"]) }
        try? await Task.sleep(nanoseconds: 200_000_000)
        runner.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
    func testJSONLogEnvelope() throws {
        let data = Data("log prefix\n{\"apps\":[]}\n".utf8)
        XCTAssertTrue(try CommandRunner.decode(SearchResponse.self, from: data).apps.isEmpty)
    }
    func testFailureDoesNotExposeRawDiagnostics() async {
        do {
            _ = try await CommandRunner().run("/usr/bin/python3", ["-c", "import sys; sys.stderr.write('private-example-secret'); sys.exit(3)"])
            XCTFail("Expected failure")
        } catch { XCTAssertFalse(error.localizedDescription.contains("private-example-secret")) }
    }
}

import Foundation
import Darwin

/// Both pipes are drained concurrently. Raw output remains in memory only.
final class CommandRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    func cancel() {
        lock.lock(); cancelled = true; let p = process; lock.unlock()
        if let p, p.isRunning {
            p.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { if p.isRunning { kill(p.processIdentifier, SIGKILL) } }
        }
    }
    func run(_ executable: String, _ arguments: [String], directory: String? = nil, update: @escaping @Sendable (String) -> Void = { _ in }) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process(), out = Pipe(), err = Pipe()
                p.executableURL = URL(fileURLWithPath: executable); p.arguments = arguments
                if let directory { p.currentDirectoryURL = URL(fileURLWithPath: directory) }
                p.standardOutput = out; p.standardError = err; p.standardInput = FileHandle.nullDevice
                var env = ProcessInfo.processInfo.environment
                env["PYTHONUNBUFFERED"] = "1"; p.environment = env
                self.lock.lock()
                if self.cancelled { self.lock.unlock(); continuation.resume(throwing: CancellationError()); return }
                self.process = p
                do { try p.run(); self.lock.unlock() }
                catch { self.process = nil; self.lock.unlock(); continuation.resume(throwing: error); return }
                let group = DispatchGroup(), captureState = OutputCapture()
                for (pipe, capture) in [(out, true), (err, false)] {
                    group.enter()
                    DispatchQueue.global().async {
                        while true {
                            let data = pipe.fileHandleForReading.availableData
                            if data.isEmpty { break }
                            captureState.append(data, stdout: capture)
                            update(String(decoding: data, as: UTF8.self))
                        }
                        group.leave()
                    }
                }
                p.waitUntilExit(); group.wait()
                self.lock.lock(); self.process = nil; let cancelled = self.cancelled; self.lock.unlock()
                if cancelled { continuation.resume(throwing: CancellationError()) }
                else if p.terminationStatus != 0 { continuation.resume(throwing: CommandError.failed(p.terminationStatus, captureState.reason)) }
                else { continuation.resume(returning: captureState.stdout) }
            }
        }
    }
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        if let result = try? decoder.decode(type, from: data) { return result }
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n").reversed() {
            if let result = try? decoder.decode(type, from: Data(line.utf8)) { return result }
        }
        throw CommandError.invalidResponse
    }
}
enum CommandError: LocalizedError {
    case failed(Int32, String), invalidResponse, setup(String)
    var errorDescription: String? {
        switch self {
        case .failed(let status, let reason): return "\(reason) (Exit \(status))."
        case .invalidResponse: return "The tool returned an unexpected response."
        case .setup(let message): return message
        }
    }
}

/// Bounded in-memory diagnostics are classified into fixed text, never exposed verbatim.
private final class OutputCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var output = Data()
    private var diagnostic = Data()
    func append(_ data: Data, stdout: Bool) {
        lock.lock(); defer { lock.unlock() }
        if stdout && output.count < 8_000_000 { output.append(data.prefix(8_000_000 - output.count)) }
        diagnostic.append(data)
        if diagnostic.count > 32_768 { diagnostic.removeFirst(diagnostic.count - 32_768) }
    }
    var stdout: Data { lock.lock(); defer { lock.unlock() }; return output }
    var reason: String {
        lock.lock(); defer { lock.unlock() }
        let text = String(decoding: diagnostic, as: UTF8.self).lowercased()
        if text.contains("modulenotfounderror") { return "Python dependencies are missing. Select the decryptor’s configured Python environment" }
        if text.contains("unsupported") || text.contains("no encrypted arm64") || text.contains("supf lacks") { return "This archive contains an unsupported encryption format or lacks the required SINF/SUPF data" }
        if text.contains("license") || text.contains("purchase") { return "An owned license is required. No purchase was attempted" }
        if text.contains("authenticate") || text.contains("password") || text.contains("session") || text.contains("keychain") { return "App Store authentication needs attention. Sign in interactively using ipatool in Terminal" }
        if text.contains("credential") { return "The credential is invalid or does not match this archive’s account" }
        if text.contains("zip") || text.contains("crc") || text.contains("mach-o") || text.contains("slice") || text.contains("inventory") || text.contains("identity") { return "Archive validation failed. The output is not marked validated; original files are preserved" }
        if text.contains("network") || text.contains("timeout") || text.contains("connection") { return "The network request failed. Check connectivity and retry" }
        return "The tool could not complete this operation. Check its setup and account access; original files are preserved"
    }
}

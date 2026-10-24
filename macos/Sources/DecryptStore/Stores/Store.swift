import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor @Observable final class Store {
    var settings: Settings { didSet { saveSettings() } }
    var query = ""
    var platform: Platform = .iphone
    var apps: [StoreApp] = []
    var selection: StoreApp.ID?
    var versions: [AppVersion] = []
    var versionIDs: [String] = []
    var showVersionIDs = false
    var artwork: [Int: URL] = [:]
    var version = ""
    var jobs: [Job] = []
    var popular: [PopularApp] = []
    var chartUpdated = ""
    var chartLoading = false
    var chartError: String?
    var openingPopular: String?
    var searching = false
    var loadingVersions = false
    var message: String?
    var section = "Discover"
    private var queue: [(UUID, () async -> Void)] = []
    private var worker: Task<Void, Never>?
    private var runner: CommandRunner?
    private var activeID: UUID?
    private var searchRunner: CommandRunner?
    private var versionRunner: CommandRunner?
    private var searchGeneration = UUID()
    private var versionGeneration = UUID()
    private let storage: URL
    var selected: StoreApp? { apps.first { $0.id == selection } }
    var completed: [Job] { jobs.filter { $0.finished && $0.output != nil } }
    init() {
        storage = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DecryptStore")
        settings = (try? Data(contentsOf: storage.appendingPathComponent("settings.json"))).flatMap { try? JSONDecoder().decode(Settings.self, from: $0) } ?? Settings()
        jobs = (try? Data(contentsOf: storage.appendingPathComponent("library.json"))).flatMap { try? JSONDecoder().decode([Job].self, from: $0) } ?? []
        for i in jobs.indices where !jobs[i].finished { jobs[i].status = "Interrupted"; jobs[i].detail = "App closed before completion. Original files preserved."; jobs[i].finished = true }
    }
    private func prepareStorage() {
        try? FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    private func saveSettings() {
        prepareStorage()
        if let data = try? JSONEncoder().encode(settings) { try? data.write(to: storage.appendingPathComponent("settings.json"), options: [.atomic]); try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storage.appendingPathComponent("settings.json").path) }
    }
    private func saveJobs() {
        prepareStorage()
        if let data = try? JSONEncoder().encode(jobs) { try? data.write(to: storage.appendingPathComponent("library.json"), options: .atomic) }
    }
    func loadChart() async {
        guard !chartLoading else { return }
        chartLoading = true; chartError = nil
        defer { chartLoading = false }
        do { let feed = try await ChartService.popular(); popular = feed.results; chartUpdated = feed.updated }
        catch { chartError = "Apple’s live chart couldn’t be loaded. Search is still available." }
    }
    func home() {
        searchRunner?.cancel(); searchGeneration = UUID(); searching = false; apps = []; query = ""; selection = nil; message = nil; resetVersions(); section = "Discover"
    }
    func openPopular(_ item: PopularApp) {
        guard openingPopular == nil else { return }
        openingPopular = item.id; message = nil
        let generation = searchGeneration
        Task {
            defer { openingPopular = nil }
            do {
                let result = try await ChartService.lookup(id: item.id)
                guard generation == searchGeneration else { return }
                resetVersions(); platform = .iphone; query = ""; apps = [result.app]; selection = result.trackId
                artwork[result.trackId] = result.artworkUrl512 ?? item.artworkUrl100
            } catch { message = "This app’s details couldn’t be loaded. Try searching for its name." }
        }
    }
    func search() {
        searchRunner?.cancel(); let generation = UUID(); searchGeneration = generation
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { searching = false; apps = []; return }
        searching = true; message = nil; apps = []; selection = nil; resetVersions()
        let tool = CommandRunner(); searchRunner = tool
        let executable = settings.ipatool, target = platform.rawValue
        Task {
            do {
                let data = try await tool.run(executable, ["--format", "json", "--non-interactive", "search", text, "--platform", target, "--limit", "30"])
                guard generation == searchGeneration else { return }
                apps = try CommandRunner.decode(SearchResponse.self, from: data).apps
                selection = apps.first?.id
                let ids = apps.map(\.id)
                Task {
                    let fetched = await ArtworkService.fetch(ids: ids)
                    guard generation == searchGeneration else { return }
                    artwork.merge(fetched, uniquingKeysWith: { _, new in new })
                }
                if apps.isEmpty { message = "No apps found for this platform." }
            } catch { if generation == searchGeneration { message = error.localizedDescription } }
            if generation == searchGeneration { searching = false }
        }
    }
    func resetVersions() { versionRunner?.cancel(); versionGeneration = UUID(); loadingVersions = false; versions = []; versionIDs = []; version = "" }
    func loadVersions() {
        guard let app = selected else { return }
        resetVersions(); loadingVersions = true
        let generation = versionGeneration, executable = settings.ipatool, target = platform.rawValue
        let tool = CommandRunner(); versionRunner = tool
        Task {
            do {
                let data = try await tool.run(executable, ["--format", "json", "--non-interactive", "list-versions", "-b", app.bundleID, "--platform", target])
                guard generation == versionGeneration else { return }
                versionIDs = try CommandRunner.decode(VersionResponse.self, from: data).externalVersionIdentifiers.reversed()
                await resolveNextVersions(app: app, target: target, executable: executable, generation: generation, tool: tool)
            } catch { if generation == versionGeneration { message = error.localizedDescription; loadingVersions = false } }
        }
    }
    func loadMoreVersions() {
        guard let app = selected, !loadingVersions else { return }
        loadingVersions = true
        let generation = versionGeneration, executable = settings.ipatool, target = platform.rawValue
        let tool = CommandRunner(); versionRunner = tool
        Task { await resolveNextVersions(app: app, target: target, executable: executable, generation: generation, tool: tool) }
    }
    private func resolveNextVersions(app: StoreApp, target: String, executable: String, generation: UUID, tool: CommandRunner) async {
        let next = Array(versionIDs.dropFirst(versions.count).prefix(12))
        for id in next {
            guard generation == versionGeneration else { return }
            versions.append(AppVersion(id: id))
            do {
                let data = try await tool.run(executable, ["--format", "json", "--non-interactive", "get-version-metadata", "-b", app.bundleID, "--platform", target, "--external-version-id", id])
                guard generation == versionGeneration else { return }
                let metadata = try CommandRunner.decode(VersionMetadata.self, from: data)
                if let index = versions.firstIndex(where: { $0.id == id }) { versions[index].displayVersion = metadata.displayVersion }
            } catch {
                guard generation == versionGeneration else { return }
                if let index = versions.firstIndex(where: { $0.id == id }) { versions[index].unavailable = true }
            }
        }
        if generation == versionGeneration { loadingVersions = false }
    }
    func choose(_ key: WritableKeyPath<Settings, String>, directory: Bool = false) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = directory; panel.canChooseFiles = !directory; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { settings[keyPath: key] = url.path }
    }
    func importIPA() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension: "ipa") ?? .zip]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { enqueueLocal(url) }
    }
    private func mutate(_ id: UUID, _ action: (inout Job) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }; action(&jobs[index]); saveJobs()
    }
    func cancel(_ id: UUID) {
        if activeID == id { runner?.cancel() }
        else { queue.removeAll { $0.0 == id }; mutate(id) { $0.status = "Cancelled"; $0.finished = true; $0.detail = "Removed from queue" } }
    }
    private func schedule(_ job: Job, operation: @escaping () async -> Void) {
        jobs.insert(job, at: 0); queue.append((job.id, operation)); section = "Activity"; saveJobs()
        guard worker == nil else { return }
        worker = Task {
            while !queue.isEmpty {
                let next = queue.removeFirst(); activeID = next.0
                await next.1(); activeID = nil; runner = nil
            }
            worker = nil
        }
    }
    private func directory(_ configuration: Settings, id: UUID) throws -> URL {
        let url = URL(fileURLWithPath: configuration.output).appendingPathComponent(id.uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    func download() {
        guard let app = selected else { return }
        let config = settings, target = platform, external = version
        let job = Job(title: app.name, platform: target.title)
        schedule(job) { [self] in
            do {
                let folder = try directory(config, id: job.id)
                let input = folder.appendingPathComponent(target == .macos ? "original.pkg" : "original.ipa")
                mutate(job.id) { $0.status = "Downloading"; $0.detail = "Downloading owned license from Apple"; $0.source = input.path }
                let tool = CommandRunner(); runner = tool
                var args = ["--format", "json", "--non-interactive", "download", "-b", app.bundleID, "--platform", target.rawValue, "-o", input.path]
                if !external.isEmpty { args += ["--external-version-id", external] }
                _ = try await tool.run(config.ipatool, args)
                guard FileManager.default.fileExists(atPath: input.path) else { throw CommandError.setup("Download returned without a package at the expected path.") }
                if target == .macos {
                    mutate(job.id) { $0.output = input.path; $0.status = "Downloaded"; $0.detail = "Mac package preserved. PKG decryption is not supported."; $0.finished = true }
                } else { try await decrypt(input, folder: folder, config: config, id: job.id, tool: tool) }
            } catch { fail(job.id, error) }
        }
    }
    func enqueueLocal(_ input: URL) {
        let config = settings, job = Job(title: input.deletingPathExtension().lastPathComponent, platform: "Local IPA", source: input.path)
        schedule(job) { [self] in
            do {
                let folder = try directory(config, id: job.id), tool = CommandRunner(); runner = tool
                try await decrypt(input, folder: folder, config: config, id: job.id, tool: tool)
            } catch { fail(job.id, error) }
        }
    }
    private func decrypt(_ input: URL, folder: URL, config: Settings, id: UUID, tool: CommandRunner) async throws {
        let credential = try FileManager.default.attributesOfItem(atPath: config.credential)
        guard (credential[.size] as? NSNumber)?.intValue == 16 else { throw CommandError.setup("Choose the matching 16-byte binary credential in Settings.") }
        guard (credential[.posixPermissions] as? NSNumber)?.intValue == 0o600 else { throw CommandError.setup("Credential file permissions must be 0600. Update them locally before continuing.") }
        let root = URL(fileURLWithPath: config.decryptor)
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("transform").path), FileManager.default.fileExists(atPath: root.appendingPathComponent("decrypt.py").path) else { throw CommandError.setup("Choose a built fairplay-decrypt folder in Settings.") }
        let output = folder.appendingPathComponent("decrypted.ipa")
        mutate(id) { $0.status = "Decrypting"; $0.detail = "Processing supported arm64 binaries" }
        _ = try await tool.run(config.python, [root.appendingPathComponent("decrypt.py").path, input.path, output.path, "--credential", config.credential], directory: root.path) { text in
            // Expose only numeric progress; never raw subprocess output or credentials.
            for line in text.split(separator: "\n") {
                let token = line.split(separator: " ").first ?? ""
                let parts = token.split(separator: "/")
                if parts.count == 2, let done = Double(parts[0]), let total = Double(parts[1]), total > 0 {
                    Task { @MainActor in self.mutate(id) { if $0.status == "Decrypting" && !$0.finished { $0.progress = min(done / total, 1); $0.detail = "Processed \(Int(done)) of \(Int(total)) binaries" } } }
                }
            }
        }
        mutate(id) { $0.status = "Validating"; $0.progress = nil; $0.detail = "Checking ZIP CRC, identity and every architecture slice" }
        guard let auditScript = Bundle.main.url(forResource: "audit", withExtension: "py") else { throw CommandError.setup("Archive validator is missing from the app bundle.") }
        let data = try await tool.run(config.python, [auditScript.path, output.path, "--reference", input.path])
        let audit = try CommandRunner.decode(Audit.self, from: data)
        try data.write(to: folder.appendingPathComponent("validation.json"), options: .atomic)
        mutate(id) { $0.output = output.path; $0.audit = audit; $0.status = audit.encrypted == 0 ? "Validated" : "Partial"; $0.detail = audit.summary; $0.finished = true; $0.progress = 1 }
    }
    private func fail(_ id: UUID, _ error: Error) {
        mutate(id) { $0.status = error is CancellationError ? "Cancelled" : "Failed"; $0.detail = error is CancellationError ? "Stopped. Original files preserved." : error.localizedDescription; $0.finished = true; $0.progress = nil }
    }
    func reveal(_ path: String) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
}

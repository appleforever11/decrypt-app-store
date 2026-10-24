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
    var libraryItems: [LibraryItem] = []
    var loadingLibrary = false
    private var hydratingDownloads = false
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
    init(storageURL: URL? = nil) {
        storage = storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DecryptStore")
        settings = (try? Data(contentsOf: storage.appendingPathComponent("settings.json"))).flatMap { try? JSONDecoder().decode(Settings.self, from: $0) } ?? Settings()
        jobs = (try? Data(contentsOf: storage.appendingPathComponent("library.json"))).flatMap { try? JSONDecoder().decode([Job].self, from: $0) } ?? []
        libraryItems = (try? Data(contentsOf: storage.appendingPathComponent("library-items.json"))).flatMap { try? JSONDecoder().decode([LibraryItem].self, from: $0) } ?? []
        for job in jobs { rememberDecryptedJob(job) }
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
    private func saveLibrary() {
        prepareStorage()
        if let data = try? JSONEncoder().encode(libraryItems) { try? data.write(to: storage.appendingPathComponent("library-items.json"), options: .atomic) }
    }
    private func rememberDecryptedJob(_ job: Job) {
        guard job.finished, job.status == "Validated", let audit = job.audit, audit.encrypted == 0,
              let path = job.output, FileManager.default.fileExists(atPath: path) else { return }
        let item = LibraryItem(id: job.id, title: audit.appName ?? job.title, bundleID: audit.bundleID, version: audit.version, build: job.buildNumber ?? audit.buildNumber, platform: audit.platform ?? job.platform, output: path, iconURL: job.iconURL)
        if let index = libraryItems.firstIndex(where: { $0.id == item.id }) {
            var updated = item
            updated.iconURL = item.iconURL ?? libraryItems[index].iconURL
            updated.build = item.build ?? libraryItems[index].build
            guard libraryItems[index] != updated else { return }
            libraryItems[index] = updated
        } else { libraryItems.insert(item, at: 0) }
        saveLibrary()
    }
    func refreshLibrary() async {
        guard !loadingLibrary else { return }
        loadingLibrary = true
        defer { loadingLibrary = false }
        let root = URL(fileURLWithPath: settings.output)
        let recovered = await Task.detached(priority: .utility) { LibraryDiscovery.recover(from: root) }.value
        for item in recovered where !libraryItems.contains(where: { $0.id == item.id }) { libraryItems.append(item) }
        saveLibrary()
        for item in libraryItems where item.build == nil || item.platform == "IPA" {
            guard !Task.isCancelled else { return }
            let original = URL(fileURLWithPath: item.output).deletingLastPathComponent().appendingPathComponent("original.ipa").path
            if let metadata = await packageMetadata(paths: [item.output, original]), metadata.bundleID == item.bundleID, metadata.version == item.version,
               let index = libraryItems.firstIndex(where: { $0.id == item.id }) {
                libraryItems[index].title = metadata.appName; libraryItems[index].build = metadata.buildNumber; libraryItems[index].platform = metadata.platform
            }
        }
        saveLibrary()
        for item in libraryItems where item.iconURL == nil {
            guard !Task.isCancelled else { return }
            if let details = await DownloadArtworkService.lookup(appID: nil, bundleID: item.bundleID),
               let index = libraryItems.firstIndex(where: { $0.id == item.id }) {
                libraryItems[index].iconURL = details.artworkUrl512 ?? details.artworkUrl100
                if libraryItems[index].title == item.bundleID { libraryItems[index].title = details.trackName }
            }
            saveLibrary()
        }
    }
    private func packageMetadata(paths: [String]) async -> PackageMetadata? {
        guard let script = Bundle.main.url(forResource: "audit", withExtension: "py") else { return nil }
        for path in paths where path.lowercased().hasSuffix(".ipa") && FileManager.default.fileExists(atPath: path) {
            if let data = try? await CommandRunner().run(settings.python, [script.path, path, "--metadata-only"]),
               let metadata = try? CommandRunner.decode(PackageMetadata.self, from: data) { return metadata }
        }
        return nil
    }
    func clearDownloads() {
        queue.removeAll()
        runner?.cancel()
        jobs.removeAll()
        saveJobs()
    }
    func hydrateDownloads() async {
        guard !hydratingDownloads else { return }
        hydratingDownloads = true
        defer { hydratingDownloads = false }
        for job in jobs where job.finished && job.buildNumber == nil {
            guard !Task.isCancelled else { return }
            if let metadata = await packageMetadata(paths: [job.output, job.source].compactMap { $0 }) {
                mutate(job.id) { $0.bundleID = metadata.bundleID; $0.appVersion = metadata.version; $0.buildNumber = metadata.buildNumber; $0.title = metadata.appName }
            }
        }
        for job in jobs where job.iconURL == nil {
            guard !Task.isCancelled else { return }
            if let details = await DownloadArtworkService.lookup(appID: job.appID, bundleID: job.bundleID ?? job.audit?.bundleID) {
                mutate(job.id) { $0.iconURL = details.artworkUrl512 ?? details.artworkUrl100 }
            }
        }
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
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }; action(&jobs[index]); rememberDecryptedJob(jobs[index]); saveJobs()
    }
    func cancel(_ id: UUID) {
        if activeID == id { runner?.cancel() }
        else { queue.removeAll { $0.0 == id }; mutate(id) { $0.status = "Cancelled"; $0.finished = true; $0.detail = "Removed from queue" } }
    }
    private func schedule(_ job: Job, operation: @escaping () async -> Void) {
        jobs.insert(job, at: 0); Task { await self.hydrateDownloads() }; queue.append((job.id, operation)); section = "Downloads"; saveJobs()
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
        let displayVersion = external.isEmpty ? app.version : versions.first(where: { $0.id == external })?.displayVersion
        let job = Job(title: app.name, platform: target.title, appID: app.id, bundleID: app.bundleID, appVersion: displayVersion, externalVersionID: external.isEmpty ? nil : external, iconURL: artwork[app.id])
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
                } else { try await decrypt(input, folder: folder, config: config, id: job.id, tool: tool, platform: target.rawValue) }
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
    private func decrypt(_ input: URL, folder: URL, config: Settings, id: UUID, tool: CommandRunner, platform: String? = nil) async throws {
        if let script = Bundle.main.url(forResource: "audit", withExtension: "py"),
           let data = try? await tool.run(config.python, [script.path, input.path, "--metadata-only"]),
           let metadata = try? CommandRunner.decode(PackageMetadata.self, from: data) {
            mutate(id) { $0.title = metadata.appName; $0.bundleID = metadata.bundleID; $0.appVersion = metadata.version; $0.buildNumber = metadata.buildNumber }
            Task { await self.hydrateDownloads() }
        }
        let credential = try FileManager.default.attributesOfItem(atPath: config.credential)
        guard (credential[.size] as? NSNumber)?.intValue == 16 else { throw CommandError.setup("Choose the matching 16-byte binary credential in Settings.") }
        guard (credential[.posixPermissions] as? NSNumber)?.intValue == 0o600 else { throw CommandError.setup("Credential file permissions must be 0600. Update them locally before continuing.") }
        let root = URL(fileURLWithPath: config.decryptor)
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("transform").path), FileManager.default.fileExists(atPath: root.appendingPathComponent("decrypt.py").path) else { throw CommandError.setup("Choose a built fairplay-decrypt folder in Settings.") }
        let output = folder.appendingPathComponent(".decrypting.ipa")
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
        let namedOutput = try ArchiveFilename.finalize(output, audit: audit, platform: platform)
        mutate(id) { $0.output = namedOutput.path; $0.audit = audit; $0.appVersion = audit.version; $0.buildNumber = audit.buildNumber; $0.bundleID = audit.bundleID; $0.status = audit.encrypted == 0 ? "Validated" : "Partial"; $0.detail = audit.summary; $0.finished = true; $0.progress = 1 }
    }
    private func fail(_ id: UUID, _ error: Error) {
        mutate(id) { $0.status = error is CancellationError ? "Cancelled" : "Failed"; $0.detail = error is CancellationError ? "Stopped. Original files preserved." : error.localizedDescription; $0.finished = true; $0.progress = nil }
    }
    func reveal(_ path: String) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
}

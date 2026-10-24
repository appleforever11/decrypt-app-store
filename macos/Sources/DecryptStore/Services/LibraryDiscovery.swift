import Foundation

/// Recover only this app's UUID job folders with a successful validation report.
/// Never enumerate the Mac's installed applications or arbitrary IPA folders.
enum LibraryDiscovery {
    static func recover(from root: URL) -> [LibraryItem] {
        let manager = FileManager.default
        guard let folders = try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return [] }
        return folders.compactMap { folder in
            guard let id = UUID(uuidString: folder.lastPathComponent),
                  let data = try? Data(contentsOf: folder.appendingPathComponent("validation.json")),
                  let audit = try? JSONDecoder().decode(Audit.self, from: data),
                  audit.crcValid, audit.inventoryMatches, audit.identityMatches, audit.encrypted == 0,
                  let files = try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles),
                  let output = files.first(where: { $0.lastPathComponent == "decrypted.ipa" || $0.lastPathComponent.hasSuffix("-decrypted.ipa") }) else { return nil }
            return LibraryItem(id: id, title: audit.appName ?? audit.bundleID, bundleID: audit.bundleID, version: audit.version, build: audit.buildNumber, platform: audit.platform ?? "IPA", output: output.path, iconURL: nil)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}

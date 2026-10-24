import SwiftUI
import AppKit

struct LibraryView: View {
    @Bindable var store: Store
    @State private var query = ""
    private var filtered: [LibraryItem] {
        store.libraryItems.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.bundleID.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search your decrypted apps", text: $query).textFieldStyle(.plain)
                Text("\(store.libraryItems.count) apps").font(.subheadline).foregroundStyle(.secondary)
                Button { Task { await store.refreshLibrary() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }.disabled(store.loadingLibrary).buttonStyle(.glass)
            }.padding(16).glassEffect(in: .rect(cornerRadius: 20)).padding(24)
            if store.loadingLibrary && store.libraryItems.isEmpty {
                Spacer(); ProgressView("Loading your decrypted apps…"); Spacer()
            } else if filtered.isEmpty {
                ContentUnavailableView("Your decrypted apps", systemImage: "square.stack.3d.up", description: Text("Apps successfully decrypted through this app appear here. Your library stays available when download history is cleared."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { item in LibraryAppRow(item: item, store: store) }
                    }.padding(.horizontal, 24).padding(.bottom, 24)
                }
            }
        }.task { await store.refreshLibrary() }
    }
}

private struct LibraryAppRow: View {
    let item: LibraryItem
    let store: Store
    // Resolve only a known library bundle ID, and require its exact version.
    // A desktop app sharing an iOS bundle ID must not be mistaken for this output.
    private var installedURL: URL? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID),
              let bundle = Bundle(url: url), bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == item.version else { return nil }
        return url
    }
    var body: some View {
        HStack(spacing: 16) {
            if let installedURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: installedURL.path)).resizable().scaledToFit().frame(width: 56, height: 56)
            } else { AppArtwork(url: item.iconURL, size: 56) }
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title).font(.headline)
                Text("\(item.platformLabel) · Version \(item.version) · Build \(item.build ?? (store.loadingLibrary ? "Loading…" : "Unavailable"))").font(.subheadline).foregroundStyle(.secondary)
                Text(installedURL == nil ? "Decrypted IPA" : "Installed locally").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button { store.reveal(installedURL?.path ?? item.output) } label: { Label("Show in Finder", systemImage: "folder") }.buttonStyle(.glass)
                .disabled(installedURL == nil && !FileManager.default.fileExists(atPath: item.output))
        }.padding(20).background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 18))
    }
}

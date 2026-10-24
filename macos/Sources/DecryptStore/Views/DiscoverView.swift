import SwiftUI

struct DiscoverView: View {
    @Bindable var store: Store
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search the App Store", text: $store.query).textFieldStyle(.plain).onSubmit { store.search() }
                Picker("Platform", selection: $store.platform) { ForEach(Platform.allCases) { Text($0.title).tag($0) } }.labelsHidden().frame(width: 155)
                Button("Search") { store.search() }.buttonStyle(.glassProminent).disabled(store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(16).glassEffect(.regular, in: .rect(cornerRadius: 20)).padding(24)
            if let message = store.message { Text(message).font(.callout).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.bottom, 12).textSelection(.enabled) }
            if store.searching {
                Spacer(); ProgressView("Searching \(store.platform.title)…"); Spacer()
            } else if store.apps.isEmpty {
                if store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    WelcomeView(store: store)
                } else {
                    ContentUnavailableView.search(text: store.query)
                }
            } else {
                HSplitView {
                    List(store.apps, selection: $store.selection) { app in
                        HStack(spacing: 12) {
                            AppArtwork(url: store.artwork[app.id], size: 44)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(app.name).font(.headline).lineLimit(2)
                                Text(app.bundleID).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }.padding(.vertical, 7).tag(app.id)
                    }.listStyle(.inset).frame(minWidth: 270)
                    if let app = store.selected { detail(app).frame(minWidth: 300, idealWidth: 360, maxWidth: 430) }
                }
            }
        }
        .onChange(of: store.platform) { _, _ in if !store.query.isEmpty { store.search() } }
        .onChange(of: store.selection) { _, _ in store.resetVersions() }
    }
    private func detail(_ app: StoreApp) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                AppArtwork(url: store.artwork[app.id], size: 88)
                VStack(alignment: .leading, spacing: 8) {
                    Text(app.name).font(.title2.bold())
                    Text(app.bundleID).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                LabeledContent("Current version", value: app.version)
                LabeledContent("Platform", value: store.platform.title)
                if let platforms = app.platforms { Text("Available for " + platforms.compactMap { Platform(rawValue: $0)?.title }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary) }
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Version").font(.headline)
                    Picker("Version", selection: $store.version) {
                        Text("Latest available").tag("")
                        ForEach(store.versions) { item in
                            Text(store.showVersionIDs ? "\(item.label) • ID \(item.id)" : item.label).tag(item.id)
                        }
                    }.labelsHidden()
                    if store.versionIDs.isEmpty {
                        Button(store.loadingVersions ? "Loading versions…" : "Load historical versions") { store.loadVersions() }.disabled(store.loadingVersions)
                    } else {
                        Text("\(store.versions.count) of \(store.versionIDs.count) releases\(store.loadingVersions ? " • Resolving…" : "")").font(.caption).foregroundStyle(.secondary)
                        if store.versions.count < store.versionIDs.count { Button("Load older versions") { store.loadMoreVersions() }.disabled(store.loadingVersions) }
                        Toggle("Show external version IDs", isOn: $store.showVersionIDs).font(.caption)
                    }
                }
                Button { store.download() } label: { Label(store.platform == .macos ? "Download package" : "Download & decrypt", systemImage: "arrow.down") .frame(maxWidth: .infinity) }.buttonStyle(.glassProminent).controlSize(.large)
                Text(app.price > 0 ? "Paid app: an existing license is required. This app never purchases a license." : "Uses your existing App Store session and owned license. No purchase is attempted.").font(.caption).foregroundStyle(.secondary)
                Text("Supported IPA slices are decrypted locally. Unsupported slices are reported after validation.").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }
    }
}

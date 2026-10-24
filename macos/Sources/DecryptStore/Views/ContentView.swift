import SwiftUI

struct ContentView: View {
    @Bindable var store: Store
    var body: some View {
        NavigationSplitView {
            List(selection: $store.section) {
                Section("Workspace") {
                    Label("Discover", systemImage: "square.grid.2x2").tag("Discover")
                    Label("Downloads", systemImage: "arrow.down.circle").badge(store.jobs.filter { !$0.finished }.count).tag("Downloads")
                    Label("Library", systemImage: "square.stack.3d.up").tag("Library")
                }
                Section("About") { Label("Capabilities", systemImage: "checkmark.shield").tag("Capabilities") }
            }.listStyle(.sidebar).navigationSplitViewColumnWidth(min: 180, ideal: 205)
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("On your Mac", systemImage: "lock.shield").font(.headline)
                        Text("Your account. Your files.").font(.caption).foregroundStyle(.secondary)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                }
        } detail: {
            Group {
                switch store.section {
                case "Downloads": DownloadsView(store: store)
                case "Library": LibraryView(store: store)
                case "Capabilities": CapabilitiesView()
                default: DiscoverView(store: store)
                }
            }.navigationTitle(store.section)
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItem { Button { store.home() } label: { Label("Storefront", systemImage: "house") }.help("Return to the storefront") }
            ToolbarItem { Button { store.importIPA() } label: { Label("Open IPA", systemImage: "doc.badge.plus") }.help("Decrypt a local IPA") }
            ToolbarSpacer(.fixed)
            ToolbarItem { SettingsLink { Label("Settings", systemImage: "gearshape") } }
        }
    }
}
struct CapabilitiesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Label("Know what’s supported", systemImage: "checkmark.shield").font(.largeTitle.bold())
                Text("A package download is only the beginning. Every decrypted IPA is checked independently before it enters your validated library.").font(.title3).foregroundStyle(.secondary)
                GroupBox("App Store discovery & download") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Platform.allCases) { platform in Label(platform.title, systemImage: platform.symbol) }
                        Text("Availability depends on the app, storefront and owned license. Historical identifiers are supplied by Apple; a listed version may no longer be downloadable.").font(.callout).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
                GroupBox("Local decryption") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Supported arm64 IPA formats", systemImage: "cpu")
                        Text("Requires a matching account’s 16-byte credential and a built fairplay-decrypt checkout. Unsupported formats fail explicitly. Mac PKG decryption is unavailable; Watch and other architecture slices may remain encrypted.")
                        Text("Validation checks ZIP CRC, archive inventory, app identity and every Mach-O encryption command. A clear archive does not establish installability or runtime compatibility.").foregroundStyle(.secondary)
                    }.padding(10)
                }
                Label("No purchases, passwords or security-setting changes", systemImage: "person.badge.shield.checkmark").foregroundStyle(.secondary)
            }.padding(32).frame(maxWidth: 850, alignment: .leading)
        }
    }
}

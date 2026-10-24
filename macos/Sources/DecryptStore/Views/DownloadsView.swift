import SwiftUI

struct DownloadsView: View {
    @Bindable var store: Store
    @State private var report: Job?
    @State private var confirmingClear = false
    var displayed: [Job] { store.jobs }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your downloads").font(.title2.bold())
                    Text("\(store.jobs.filter { !$0.finished }.count) active · \(store.jobs.filter(\.finished).count) finished").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button { confirmingClear = true } label: { Label("Clear All Downloads", systemImage: "trash") }.buttonStyle(.glass).disabled(store.jobs.isEmpty)
            }.padding(24)
            if displayed.isEmpty {
                ContentUnavailableView("No downloads yet", systemImage: "arrow.down.circle", description: Text("Active downloads, completed packages and local IPA jobs appear here."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(displayed) { job in
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .top, spacing: 16) {
                                    AppArtwork(url: job.iconURL, size: 52)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(job.title).font(.headline)
                                        Text(job.platform).font(.caption).foregroundStyle(.secondary)
                                        Text("Version \(job.appVersion ?? job.audit?.version ?? (job.finished ? "Unavailable" : "Pending")) · Build \(job.buildNumber ?? job.audit?.buildNumber ?? (job.finished ? "Unavailable" : "Pending"))").font(.caption).foregroundStyle(.secondary)
                                        if let external = job.externalVersionID { Text("Store ID \(external)").font(.caption2).foregroundStyle(.tertiary) }
                                    }
                                    Spacer()
                                    Text(job.status).font(.subheadline.weight(.medium)).foregroundStyle(color(job))
                                }
                                Text(job.detail).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                                if !job.finished && job.status != "Queued" {
                                    if let progress = job.progress { ProgressView(value: progress) } else { ProgressView().controlSize(.small) }
                                }
                                HStack {
                                    if !job.finished { Button("Cancel", role: .destructive) { store.cancel(job.id) } }
                                    if let path = job.output { Button("Reveal output") { store.reveal(path) } }
                                    if let source = job.source { Button("Reveal original") { store.reveal(source) } }
                                    if job.audit != nil { Button("Validation report") { report = job } }
                                    Spacer()
                                }.buttonStyle(.bordered)
                            }.padding(20).background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 18))
                        }
                    }.padding(24)
                }
            }
        }
        .task { await store.hydrateDownloads() }
        .confirmationDialog("Clear all downloads?", isPresented: $confirmingClear) {
            Button("Clear All Downloads", role: .destructive) { store.clearDownloads() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Active and queued jobs will be cancelled and download history will be cleared. Downloaded files stay on your Mac.")
        }
        .sheet(item: $report) { job in
            VStack(alignment: .leading, spacing: 16) {
                Text("Archive validation").font(.title.bold())
                if let audit = job.audit {
                    Text("\(audit.bundleID) • \(audit.version)").foregroundStyle(.secondary)
                    Label("ZIP CRC, inventory and identity passed", systemImage: "checkmark.shield")
                    Text(audit.summary).font(.headline).foregroundStyle(audit.encrypted == 0 ? .green : .orange)
                    Table(audit.slices) {
                        TableColumn("Binary") { Text($0.path).help($0.path) }
                        TableColumn("Architecture", value: \.architecture).width(100)
                        TableColumn("Encryption") { Text($0.cryptid == 0 ? "Clear" : "Encrypted (\($0.cryptid))").foregroundStyle($0.cryptid == 0 ? Color.secondary : Color.orange) }.width(130)
                    }
                    Text("Static validation does not establish installation or runtime compatibility.").font(.caption).foregroundStyle(.secondary)
                }
                HStack { Spacer(); Button("Done") { report = nil }.keyboardShortcut(.defaultAction) }
            }.padding(24).frame(width: 820, height: 520)
        }
    }
    private func color(_ job: Job) -> Color { job.status == "Validated" ? .green : job.status == "Partial" ? .orange : job.status == "Failed" ? .red : .accentColor }
}

import SwiftUI

struct ActivityView: View {
    @Bindable var store: Store
    let library: Bool
    @State private var report: Job?
    var displayed: [Job] { library ? store.completed : store.jobs }
    var body: some View {
        Group {
            if displayed.isEmpty {
                ContentUnavailableView(library ? "Your local library" : "Ready when you are", systemImage: library ? "square.stack.3d.up" : "arrow.down.circle", description: Text(library ? "Downloaded packages and validated archives appear here." : "Downloads and local decryption jobs appear here."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(displayed) { job in
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .top, spacing: 16) {
                                    Image(systemName: symbol(job)).font(.title2).foregroundStyle(color(job)).frame(width: 34)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(job.title).font(.headline)
                                        Text(job.platform).font(.caption).foregroundStyle(.secondary)
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
        }.sheet(item: $report) { job in
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
    private func symbol(_ job: Job) -> String { job.status == "Validated" ? "checkmark.seal" : job.status == "Partial" ? "exclamationmark.shield" : job.status == "Failed" ? "xmark.circle" : "shippingbox" }
    private func color(_ job: Job) -> Color { job.status == "Validated" ? .green : job.status == "Partial" ? .orange : job.status == "Failed" ? .red : .accentColor }
}

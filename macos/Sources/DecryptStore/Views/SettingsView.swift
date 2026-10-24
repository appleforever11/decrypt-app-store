import SwiftUI
struct SettingsView: View {
    @Bindable var store: Store
    var body: some View {
        Form {
            Section("App Store") {
                path("ipatool executable", key: \.ipatool)
                Text("Uses the existing Keychain session. If sign-in expires, authenticate interactively with ipatool in Terminal.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Local decryption") {
                path("Python environment", key: \.python)
                path("Built decryptor folder", key: \.decryptor, directory: true)
                path("Credential file", key: \.credential)
                Text("Select the matching account’s raw 16-byte binary file (0600 permissions). Only its path is saved. The credential is never copied into the app.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Library") { path("Output folder", key: \.output, directory: true) }
        }.formStyle(.grouped).padding(12).frame(width: 680, height: 540)
    }
    private func path(_ title: String, key: WritableKeyPath<Settings, String>, directory: Bool = false) -> some View {
        LabeledContent(title) {
            HStack { TextField("Choose a path", text: Binding(get: { store.settings[keyPath: key] }, set: { store.settings[keyPath: key] = $0 })).textFieldStyle(.roundedBorder); Button("Choose…") { store.choose(key, directory: directory) } }
        }
    }
}

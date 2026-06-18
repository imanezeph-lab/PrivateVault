import SwiftUI

struct AutoBackupSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var autoBackup = AutoBackupManager.shared
    @EnvironmentObject private var viewModel: VaultViewModel
    @State private var showPassphrase = false
    @State private var showExternalFolderPicker = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $autoBackup.isEnabled) {
                        Label("Auto Backup", systemImage: "clock.arrow.circlepath")
                    }

                    if autoBackup.isEnabled {
                        if let date = autoBackup.lastBackupDate {
                            HStack {
                                Label("Last Backup", systemImage: "checkmark.circle")
                                Spacer()
                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if autoBackup.hasExternalLocation {
                            HStack {
                                Label("External Location", systemImage: "externaldrive")
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }

                        Button {
                            showExternalFolderPicker = true
                        } label: {
                            Label(autoBackup.hasExternalLocation ? "Change Location" : "Set External Location",
                                  systemImage: "folder.badge.plus")
                        }

                        if autoBackup.hasExternalLocation {
                            Button(role: .destructive) {
                                autoBackup.clearExternalLocation()
                            } label: {
                                Label("Remove Location", systemImage: "xmark.circle")
                                    .foregroundStyle(.red)
                            }
                        }

                        if let error = autoBackup.lastError {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button {
                            withAnimation { showPassphrase.toggle() }
                        } label: {
                            Label(showPassphrase ? "Hide Recovery Passphrase" : "Show Recovery Passphrase",
                                  systemImage: "key")
                        }
                        if showPassphrase {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Save this passphrase - you need it to restore auto-backups:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(autoBackup.backupPassphrase)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                } header: {
                    Text("Auto Backup")
                } footer: {
                    if autoBackup.isEnabled && autoBackup.hasExternalLocation {
                        Text("Backups are automatically saved to your chosen location every time you make a change. They survive app deletion.")
                    } else if autoBackup.isEnabled {
                        Text("Local backups are saved inside the app. Set an external location (iCloud Drive) for backups that survive app deletion.")
                    }
                }

                Section {
                    Button {
                        Task {
                            autoBackup.triggerBackup(viewModel: viewModel)
                        }
                    } label: {
                        Label("Back Up Now", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Manual Backup")
                }
            }
            .navigationTitle("Backup Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showExternalFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if autoBackup.setupExternalLocation(from: url) {
                        autoBackup.lastError = nil
                    }
                case .failure:
                    break
                }
            }
        }
    }
}
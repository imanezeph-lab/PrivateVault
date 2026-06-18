import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var viewModel: VaultViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var autoBackup = AutoBackupManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var backupMode: BackupMode = .export
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var backupResult: BackupResult?
    @State private var showPassphraseSheet = false
    @State private var showFileExporter = false
    @State private var showFileImporter = false
    @State private var exportedData: Data?
    @State private var importedData: Data?
    @State private var isProcessing = false
    @State private var showPassphrase = false
    @State private var showExternalFolderPicker = false

    enum BackupMode { case export, `import` }
    enum BackupResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        NavigationStack {
            List {
                backupSection
                autoBackupSection
                navigationSection
                themeSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPassphraseSheet) {
                passphraseSheet
            }
            .fileExporter(
                isPresented: $showFileExporter,
                document: exportedData.map { BackupDocument(data: $0) },
                contentType: .vaultBackup,
                defaultFilename: "PrivateVault-\(formattedDate()).vault"
            ) { result in
                switch result {
                case .success: backupResult = .success("Backup saved!")
                case .failure(let error): backupResult = .failure(error.localizedDescription)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.vaultBackup],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first, url.startAccessingSecurityScopedResource() else {
                        backupResult = .failure("Could not access file")
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    importedData = try? Data(contentsOf: url)
                    restoreBackup()
                case .failure(let error):
                    backupResult = .failure(error.localizedDescription)
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

    @ViewBuilder
    private var backupSection: some View {
        Section {
            Button {
                backupMode = .export
                passphrase = ""
                confirmPassphrase = ""
                backupResult = nil
                showPassphraseSheet = true
            } label: {
                Label("Backup All Data", systemImage: "square.and.arrow.up")
            }

            Button {
                backupMode = .import
                passphrase = ""
                confirmPassphrase = ""
                backupResult = nil
                showPassphraseSheet = true
            } label: {
                Label("Restore from Backup", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("Backups are AES-256 encrypted. Save the .vault file anywhere \u{2014} you\u{2019}ll need your passphrase to restore.")
        }
    }

    @ViewBuilder
    private var autoBackupSection: some View {
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
                        Text("Save this passphrase \u{2014} you need it to restore auto-backups:")
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
    }

    @ViewBuilder
    private var themeSection: some View {
        Section("App Theme") {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                Button {
                    themeManager.theme = theme
                } label: {
                    HStack {
                        Image(systemName: theme.icon)
                            .foregroundStyle(.tint)
                        Text(theme.label)
                        Spacer()
                        if theme == themeManager.theme {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var navigationSection: some View {
        Section("Navigation") {
            Picker("Mode", selection: $viewModel.navigationMode) {
                ForEach(NavigationMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            Picker("Order", selection: $viewModel.navigationOrder) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
        } footer: {
            Text("Swipe: page-by-page. Scroll: continuous feed.")
        }
    }

    private var passphraseSheet: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Passphrase", text: $passphrase)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if backupMode == .export {
                        SecureField("Confirm passphrase", text: $confirmPassphrase)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text(backupMode == .export ? "Set a passphrase" : "Enter passphrase")
                } footer: {
                    if backupMode == .export {
                        Text("You\u{2019}ll need this passphrase to restore the backup. Don\u{2019}t forget it!")
                    }
                }

                if let result = backupResult {
                    Section {
                        switch result {
                        case .success(let msg):
                            Label(msg, systemImage: "checkmark.circle")
                                .foregroundStyle(.green)
                        case .failure(let msg):
                            Label(msg, systemImage: "xmark.circle")
                                .foregroundStyle(.red)
                        }
                    }
                }

                if isProcessing {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
            .navigationTitle(backupMode == .export ? "Export Backup" : "Restore Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showPassphraseSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(backupMode == .export ? "Export" : "Restore") {
                        Task { await handleBackupAction() }
                    }
                    .disabled(passphrase.isEmpty || (backupMode == .export && passphrase != confirmPassphrase) || isProcessing)
                }
            }
        }
    }

    private func handleBackupAction() async {
        isProcessing = true
        defer { isProcessing = false }

        switch backupMode {
        case .export:
            do {
                let activeItems = viewModel.items.filter { !$0.isDeleted }
                let jsonData = try BackupService.createBackup(items: activeItems)
                let encryptedData = try BackupService.encryptBackup(jsonData, passphrase: passphrase)
                exportedData = encryptedData
                showPassphraseSheet = false
                showFileExporter = true
            } catch {
                backupResult = .failure(error.localizedDescription)
            }

        case .import:
            showFileImporter = true
            showPassphraseSheet = false
        }
    }

    private func restoreBackup() {
        guard let data = importedData else {
            backupResult = .failure("No data in file")
            return
        }

        do {
            let decrypted = try BackupService.decryptBackup(data, passphrase: passphrase)
            let entries = try BackupService.extractEntries(from: decrypted)
            BackupService.restoreEntries(entries, into: viewModel)
            backupResult = .success("Restored \(entries.count) item(s)!")
        } catch {
            backupResult = .failure(error.localizedDescription)
        }
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}

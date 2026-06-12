import SwiftUI
import UniformTypeIdentifiers

struct FolderListView: View {
    @EnvironmentObject private var viewModel: VaultViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var autoBackup = AutoBackupManager.shared
    @Binding var selectedItem: MediaItem?
    @Binding var showingImport: Bool
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var folderToDelete: Folder?
    @State private var showingDeleteAlert = false
    @State private var folderToRename: Folder?
    @State private var renameText = ""

    @State private var showingBackup = false
    @State private var backupMode: BackupMode = .export
    @State private var passphrase = ""
    @State private var confirmPassphrase = ""
    @State private var backupResult: BackupResult?
    @State private var showFileExporter = false
    @State private var showFileImporter = false
    @State private var exportedData: Data?
    @State private var importedData: Data?
    @State private var isProcessing = false

    @State private var showingThemePicker = false
    @State private var showExternalFolderPicker = false
    @State private var showPassphrase = false

    enum BackupMode {
        case export, `import`
    }

    enum BackupResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    GalleryView(selectedItem: $selectedItem, showingImport: $showingImport)
                        .environmentObject(viewModel)
                        .onAppear { viewModel.selectedFolderID = nil }
                } label: {
                    Label("All Items", systemImage: "tray.full")
                        .badge(viewModel.activeItemCount())
                }
            }

            Section("Folders") {
                ForEach(viewModel.folders) { folder in
                    NavigationLink {
                        GalleryView(selectedItem: $selectedItem, showingImport: $showingImport)
                            .environmentObject(viewModel)
                            .onAppear { viewModel.selectedFolderID = folder.id }
                    } label: {
                        Label(folder.name, systemImage: folder.icon)
                            .badge(viewModel.folderItemCount(folder))
                    }
                    .contextMenu {
                        Button {
                            folderToRename = folder
                            renameText = folder.name
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            folderToDelete = folder
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            viewModel.deleteFolder(folder)
                        }
                    }
                }
            }

            Section("Quick Links") {
                NavigationLink {
                    GalleryView(selectedItem: $selectedItem, showingImport: $showingImport)
                        .environmentObject(viewModel)
                        .onAppear {
                            viewModel.selectedFolderID = nil
                            viewModel.showFavoritesOnly = true
                        }
                } label: {
                    Label("Favorites", systemImage: "star")
                        .badge(viewModel.favoriteCount())
                }

                NavigationLink {
                    TrashView()
                        .environmentObject(viewModel)
                } label: {
                    Label("Recently Deleted", systemImage: "trash")
                        .badge(viewModel.trashedItems.count)
                }
            }

            Section {
                Button {
                    backupMode = .export
                    passphrase = ""
                    confirmPassphrase = ""
                    backupResult = nil
                    showingBackup = true
                } label: {
                    Label("Backup All Data", systemImage: "square.and.arrow.up")
                }

                Button {
                    backupMode = .import
                    passphrase = ""
                    confirmPassphrase = ""
                    backupResult = nil
                    showingBackup = true
                } label: {
                    Label("Restore from Backup", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Backups are AES-256 encrypted. Save the .vault file anywhere — you'll need your passphrase to restore.")
            }

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
                        showPassphrase.toggle()
                    } label: {
                        Label(showPassphrase ? "Hide Recovery Passphrase" : "Show Recovery Passphrase",
                              systemImage: "key")
                    }
                    if showPassphrase {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Save this passphrase — you need it to restore auto-backups:")
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
                    showingThemePicker = true
                } label: {
                    Label("App Theme", systemImage: "paintbrush")
                }
            }
        }
        .navigationTitle("Private Vault")
        .onAppear {
            viewModel.selectedFolderID = nil
            viewModel.showFavoritesOnly = false
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Button {
                        showingImport = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    Button {
                        showingNewFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
        }
        .alert("New Folder", isPresented: $showingNewFolder) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) { newFolderName = "" }
            Button("Create") {
                let name = newFolderName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { viewModel.createFolder(name: name) }
                newFolderName = ""
            }
        } message: { Text("Enter a name for the new folder.") }
        .alert("Delete Folder", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { folderToDelete = nil }
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete { viewModel.deleteFolder(folder) }
                folderToDelete = nil
            }
        } message: { Text("Items in this folder will be moved out but NOT deleted.") }
        .alert("Rename Folder", isPresented: .init(
            get: { folderToRename != nil },
            set: { if !$0 { folderToRename = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { folderToRename = nil }
            Button("Save") {
                if let folder = folderToRename {
                    let name = renameText.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { viewModel.renameFolder(folder, to: name) }
                }
                folderToRename = nil
            }
        }
        .sheet(isPresented: $showingBackup) {
            backupSheet
        }
        .sheet(isPresented: $showingThemePicker) {
            themePickerSheet
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

    private var themePickerSheet: some View {
        NavigationStack {
            List {
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
            .navigationTitle("App Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingThemePicker = false }
                }
            }
        }
    }

    private var backupSheet: some View {
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
                        Text("You'll need this passphrase to restore the backup. Don't forget it!")
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
                    Button("Cancel") { showingBackup = false }
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
                showingBackup = false
                showFileExporter = true
            } catch {
                backupResult = .failure(error.localizedDescription)
            }

        case .import:
            showFileImporter = true
            showingBackup = false
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

struct BackupDocument: FileDocument {
    let data: Data

    static var readableContentTypes: [UTType] { [.vaultBackup] }

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension UTType {
    static let vaultBackup = UTType(filenameExtension: "vault") ?? .data
}

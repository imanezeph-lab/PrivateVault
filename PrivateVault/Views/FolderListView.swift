import SwiftUI
import UniformTypeIdentifiers

enum NavigationDest: Hashable {
    case allItems, favorites, trash, folder(Folder)
}

struct FolderListView: View {
    @EnvironmentObject private var viewModel: VaultViewModel
    @Binding var selectedItem: MediaItem?
    @Binding var showingImport: Bool
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var folderToDelete: Folder?
    @State private var showingDeleteAlert = false
    @State private var folderToRename: Folder?
    @State private var renameText = ""
    @State private var showingAutoBackupSettings = false

    var body: some View {
        List {
            NavigationLink(value: NavigationDest.allItems) {
                Label("All Items", systemImage: "tray.full")
                    .badge(viewModel.activeItemCount())
            }

            Section("Folders") {
                ForEach(viewModel.folders) { folder in
                    NavigationLink(value: NavigationDest.folder(folder)) {
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
                NavigationLink(value: NavigationDest.favorites) {
                    Label("Favorites", systemImage: "star")
                        .badge(viewModel.favoriteCount())
                }

                NavigationLink(value: NavigationDest.trash) {
                    Label("Recently Deleted", systemImage: "trash")
                        .badge(viewModel.trashedItems.count)
                }
            }
        }
        .navigationDestination(for: NavigationDest.self) { dest in
            switch dest {
            case .allItems:
                GalleryView(selectedItem: $selectedItem, showingImport: $showingImport)
                    .environmentObject(viewModel)
                    .onAppear {
                        viewModel.selectedFolderID = nil
                        viewModel.showFavoritesOnly = false
                    }
            case .favorites:
                GalleryView(selectedItem: $selectedItem, showingImport: $showingImport)
                    .environmentObject(viewModel)
                    .onAppear {
                        viewModel.selectedFolderID = nil
                        viewModel.showFavoritesOnly = true
                    }
            case .trash:
                TrashView()
                    .environmentObject(viewModel)
            case .folder(let folder):
                GalleryView(selectedItem: $selectedItem, showingImport: $showingImport)
                    .environmentObject(viewModel)
                    .onAppear {
                        viewModel.selectedFolderID = folder.id
                        viewModel.showFavoritesOnly = false
                    }
            }
        }
        .navigationTitle("Private Vault")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button {
                        Task { AutoBackupManager.shared.triggerBackup(viewModel: viewModel) }
                    } label: {
                        Label("Back Up Now", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingAutoBackupSettings = true
                    } label: {
                        Label("Auto Backup", systemImage: "clock.arrow.circlepath")
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
            }
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
        .sheet(isPresented: $showingAutoBackupSettings) {
            AutoBackupSettingsView()
                .environmentObject(viewModel)
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

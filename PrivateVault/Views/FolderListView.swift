import SwiftUI

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

    var body: some View {
        List {
            Section {
                NavigationLink {
                    GalleryView(selectedItem: $selectedItem, showingImport: $showingImport)
                        .environmentObject(viewModel)
                        .onAppear { viewModel.selectedFolderID = nil }
                } label: {
                    Label("All Items", systemImage: "tray.full")
                        .badge(viewModel.items.count)
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
        }
        .navigationTitle("Private Vault")
        .onAppear { viewModel.selectedFolderID = nil }
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
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
            Button("Create") {
                let name = newFolderName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    viewModel.createFolder(name: name)
                }
                newFolderName = ""
            }
        } message: {
            Text("Enter a name for the new folder.")
        }
        .alert("Delete Folder", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { folderToDelete = nil }
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete {
                    viewModel.deleteFolder(folder)
                }
                folderToDelete = nil
            }
        } message: {
            Text("Items in this folder will be moved out but NOT deleted.")
        }
        .alert("Rename Folder", isPresented: .init(
            get: { folderToRename != nil },
            set: { if !$0 { folderToRename = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { folderToRename = nil }
            Button("Save") {
                if let folder = folderToRename {
                    let name = renameText.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        viewModel.renameFolder(folder, to: name)
                    }
                }
                folderToRename = nil
            }
        }
    }
}

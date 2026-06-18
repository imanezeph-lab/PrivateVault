import SwiftUI

struct DetailView: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: VaultViewModel
    @State private var showMoveSheet = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            MediaContentView(item: item)
                .ignoresSafeArea(edges: item.type == .file ? [] : .all)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            Button {
                                viewModel.toggleFavorite(item)
                            } label: {
                                Image(systemName: item.isFavorite ? "star.fill" : "star")
                                    .foregroundStyle(item.isFavorite ? .yellow : .primary)
                            }

                            if !viewModel.folders.isEmpty {
                                Button {
                                    showMoveSheet = true
                                } label: {
                                    Image(systemName: "folder")
                                }
                            }

                            ShareLink(item: item.fileURL) {
                                Image(systemName: "square.and.arrow.up")
                            }

                            Button("Delete", role: .destructive) {
                                showDeleteConfirmation = true
                            }
                            .foregroundStyle(.red)
                        }
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
                .sheet(isPresented: $showMoveSheet) {
                    moveFolderSheet
                }
                .alert("Delete Item", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        viewModel.softDeleteItem(item)
                        dismiss()
                    }
                } message: {
                    Text("This item will be moved to Recently Deleted.")
                }
        }
    }

    private var moveFolderSheet: some View {
        NavigationStack {
            List {
                Button {
                    viewModel.moveItem(item, to: nil)
                    showMoveSheet = false
                } label: {
                    Label("No Folder (All Items)", systemImage: "tray")
                }

                ForEach(viewModel.folders) { folder in
                    Button {
                        viewModel.moveItem(item, to: folder.id)
                        showMoveSheet = false
                    } label: {
                        Label(folder.name, systemImage: folder.icon)
                    }
                }
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showMoveSheet = false }
                }
            }
        }
    }
}

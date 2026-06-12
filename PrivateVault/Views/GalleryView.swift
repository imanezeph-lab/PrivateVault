import SwiftUI

struct GalleryView: View {
    @EnvironmentObject private var viewModel: VaultViewModel
    @Binding var selectedItem: MediaItem?
    @Binding var showingImport: Bool
    @State private var itemToMove: MediaItem?
    @State private var showMoveSheet = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    private var displayItems: [MediaItem] {
        viewModel.filteredItems
    }

    var body: some View {
        Group {
            if displayItems.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "photo.on.rectangle",
                    description: Text("Tap + to import media or files")
                )
            } else if viewModel.isGrid {
                gridContent
            } else {
                listContent
            }
        }
        .navigationTitle(viewModel.currentFolderName)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation { viewModel.isGrid.toggle() }
                } label: {
                    Image(systemName: viewModel.isGrid
                          ? "list.bullet"
                          : "square.grid.2x2")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingImport = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showMoveSheet) {
            moveFolderSheet
        }
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(displayItems) { item in
                    thumbnail(for: item)
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { selectedItem = item }
                        .contextMenu { itemContextMenu(for: item) }
                }
            }
        }
    }

    private var listContent: some View {
        List {
            ForEach(displayItems) { item in
                HStack(spacing: 12) {
                    thumbnail(for: item)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.fileName)
                            .lineLimit(1)
                            .font(.subheadline)
                        Text(item.dateAdded.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.formattedSize)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Image(systemName: item.type.icon)
                        .foregroundStyle(.tint)
                }
                .contentShape(Rectangle())
                .onTapGesture { selectedItem = item }
                .contextMenu { itemContextMenu(for: item) }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteItem(displayItems[index])
                }
            }
        }
    }

    @ViewBuilder
    private func itemContextMenu(for item: MediaItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            Label("View", systemImage: "eye")
        }

        if !viewModel.folders.isEmpty {
            Button {
                itemToMove = item
                showMoveSheet = true
            } label: {
                Label("Move to Folder", systemImage: "folder")
            }
        }

        Button(role: .destructive) {
            viewModel.deleteItem(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private var moveFolderSheet: some View {
        if let item = itemToMove {
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
                                .badge(viewModel.folderItemCount(folder))
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

    @ViewBuilder
    private func thumbnail(for item: MediaItem) -> some View {
        if item.type == .image || item.type == .gif {
            if let image = UIImage(contentsOfFile: item.fileURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                fallbackIcon(for: item)
            }
        } else {
            ZStack {
                Color(.systemGray5)
                Image(systemName: item.type.icon)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func fallbackIcon(for item: MediaItem) -> some View {
        Color(.systemGray5)
            .overlay {
                Image(systemName: item.type.icon)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}

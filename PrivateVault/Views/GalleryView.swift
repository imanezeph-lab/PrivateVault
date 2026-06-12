import SwiftUI

struct GalleryView: View {
    @EnvironmentObject private var viewModel: VaultViewModel
    @Binding var selectedItem: MediaItem?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    var body: some View {
        Group {
            if viewModel.items.isEmpty {
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
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(viewModel.items) { item in
                    thumbnail(for: item)
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { selectedItem = item }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteItem(item)
                            }
                        }
                }
            }
        }
    }

    private var listContent: some View {
        List {
            ForEach(viewModel.items) { item in
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
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteItem(viewModel.items[index])
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

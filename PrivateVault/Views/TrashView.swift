import SwiftUI

struct TrashView: View {
    @EnvironmentObject private var viewModel: VaultViewModel
    @State private var showEmptyConfirmation = false

    var body: some View {
        Group {
            if viewModel.trashedItems.isEmpty {
                ContentUnavailableView(
                    "Trash is Empty",
                    systemImage: "trash.slash",
                    description: Text("Deleted items appear here")
                )
            } else {
                List {
                    ForEach(viewModel.trashedItems) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.type.icon)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.fileName)
                                    .lineLimit(1)
                                    .font(.subheadline)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                                Text("Deleted \(item.deletedDate?.formatted(date: .abbreviated, time: .shortened) ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            Button {
                                viewModel.restoreItem(item)
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                                    .foregroundStyle(.tint)
                            }
                            .buttonStyle(.plain)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                viewModel.permanentlyDeleteItem(item)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button("Restore") {
                                viewModel.restoreItem(item)
                            }
                            .tint(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .toolbar {
            if !viewModel.trashedItems.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Empty Trash", role: .destructive) {
                        showEmptyConfirmation = true
                    }
                }
            }
        }
        .alert("Empty Trash?", isPresented: $showEmptyConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Empty", role: .destructive) {
                withAnimation {
                    viewModel.emptyTrash()
                }
            }
        } message: {
            Text("This permanently deletes \(viewModel.trashedItems.count) item(s). This cannot be undone.")
        }
    }
}

import SwiftUI
import AVKit
import QuickLook

struct DetailView: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: VaultViewModel
    @State private var showMoveSheet = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                switch item.type {
                case .image, .gif:
                    mediaViewer
                case .video:
                    videoViewer
                case .file:
                    documentViewer
                }
            }
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

    private var mediaViewer: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                Image(uiImage: UIImage(contentsOfFile: item.fileURL.path) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height)
            }
        }
    }

    private var videoViewer: some View {
        VideoPlayer(player: AVPlayer(url: item.fileURL))
    }

    private var documentViewer: some View {
        QuickLookPreview(url: item.fileURL)
            .ignoresSafeArea()
    }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_: UINavigationController, context _: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in _: QLPreviewController) -> Int { 1 }
        func previewController(_: QLPreviewController, previewItemAt _: Int) -> QLPreviewItem { url as QLPreviewItem }
    }
}

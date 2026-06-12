import SwiftUI
import AVKit
import QuickLook

struct DetailView: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: VaultViewModel

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
                        ShareLink(item: item.fileURL) {
                            Image(systemName: "square.and.arrow.up")
                        }

                        Button("Delete", role: .destructive) {
                            viewModel.deleteItem(item)
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
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

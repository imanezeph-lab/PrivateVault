import SwiftUI
import AVKit
import QuickLook

struct MediaContentView: View {
    let item: MediaItem
    @State private var player: AVPlayer?
    @State private var playerStatus: PlayerStatus = .loading
    @State private var showUnsupportedAlert = false

    enum PlayerStatus {
        case loading, ready, failed
    }

    var body: some View {
        Group {
            switch item.type {
            case .image, .gif:
                imageViewer
            case .video:
                videoViewer
            case .file:
                documentViewer
            }
        }
        .task(id: item.id) {
            guard item.type == .video else { return }
            await setupPlayer()
        }
        .onDisappear {
            teardownPlayer()
        }
        .alert("Unsupported Format", isPresented: $showUnsupportedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This video format cannot be played on this device.")
        }
    }

    private func setupPlayer() async {
        let asset = AVAsset(url: item.fileURL)
        guard let isPlayable = try? await asset.load(.isPlayable), isPlayable else {
            playerStatus = .failed
            showUnsupportedAlert = true
            return
        }
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: playerItem)
        self.player?.play()
        self.playerStatus = .ready
    }

    private func teardownPlayer() {
        player?.pause()
        player = nil
        playerStatus = .loading
    }

    private var imageViewer: some View {
        Color.black
            .overlay {
                if let image = UIImage(contentsOfFile: item.fileURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
    }

    private var videoViewer: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if playerStatus == .loading {
                ProgressView()
                    .tint(.white)
            } else if playerStatus == .failed {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Cannot play this video")
                        .foregroundStyle(.secondary)
                }
            }
        }
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

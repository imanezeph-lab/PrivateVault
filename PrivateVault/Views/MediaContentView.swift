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
        ZoomableScrollView {
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
        .ignoresSafeArea()
        .background(Color.black)
    }

    private var videoViewer: some View {
        ZoomableScrollView {
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
        .ignoresSafeArea()
        .background(Color.black)
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

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5.0
        scrollView.minimumZoomScale = 1.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .black

        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostedView.frame = scrollView.bounds
        hostedView.backgroundColor = .clear
        scrollView.addSubview(hostedView)

        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = self.content
        let hostedView = context.coordinator.hostingController.view!
        hostedView.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(hostingController: UIHostingController(rootView: self.content))
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>

        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let hostingView = hostingController.view!
            let scrollViewSize = scrollView.bounds.size
            let viewSize = hostingView.frame.size
            
            let insetX = max(0, (scrollViewSize.width - viewSize.width) / 2)
            let insetY = max(0, (scrollViewSize.height - viewSize.height) / 2)
            
            scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = recognizer.view as? UIScrollView else { return }
            
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let pointInView = recognizer.location(in: hostingController.view)
                let scrollViewSize = scrollView.bounds.size
                
                let w = scrollViewSize.width / scrollView.maximumZoomScale
                let h = scrollViewSize.height / scrollView.maximumZoomScale
                let x = pointInView.x - (w / 2.0)
                let y = pointInView.y - (h / 2.0)
                
                let rectToZoomTo = CGRect(x: x, y: y, width: w, height: h)
                scrollView.zoom(to: rectToZoomTo, animated: true)
            }
        }
    }
}

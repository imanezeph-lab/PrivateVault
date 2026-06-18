import SwiftUI
import AVKit
import AVFoundation
import UIKit
import QuickLook
import Combine

struct MediaContentView: View {
    let item: MediaItem
    @Binding var showUI: Bool
    
    @State private var player: AVPlayer?
    @State private var playerStatus: PlayerStatus = .loading
    @State private var showUnsupportedAlert = false
    @State private var isMuted = false
    @State private var isPlaying = true

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
        self.player?.isMuted = isMuted
        self.player?.play()
        self.isPlaying = true
        self.playerStatus = .ready
    }

    private func teardownPlayer() {
        player?.pause()
        player = nil
        isPlaying = false
        playerStatus = .loading
    }

    private var imageViewer: some View {
        ZoomableScrollView(onSingleTap: {
            withAnimation { self.showUI.toggle() }
        }) {
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
        ZoomableScrollView(onSingleTap: {
            withAnimation { self.showUI.toggle() }
        }) {
            ZStack {
                Color.black
                if let player = player {
                    CustomVideoPlayerView(player: player)
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
        .overlay(alignment: .bottom) {
            if playerStatus == .ready, let player = player, showUI {
                VideoControlsView(player: player, isPlaying: $isPlaying, isMuted: $isMuted)
                    .padding(.bottom, 20)
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

struct CustomVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> UIView {
        let view = VideoPlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? VideoPlayerUIView)?.playerLayer.player = player
    }
}

class VideoPlayerUIView: UIView {
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    override class var layerClass: AnyClass { AVPlayerLayer.self }
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    private var content: Content
    var onSingleTap: (() -> Void)?

    init(onSingleTap: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.onSingleTap = onSingleTap
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
        
        let singleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.require(toFail: doubleTapGesture)
        scrollView.addGestureRecognizer(singleTapGesture)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.hostingController.rootView = self.content
        let hostedView = context.coordinator.hostingController.view!
        hostedView.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self, hostingController: UIHostingController(rootView: self.content))
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableScrollView
        var hostingController: UIHostingController<Content>

        init(parent: ZoomableScrollView, hostingController: UIHostingController<Content>) {
            self.parent = parent
            self.hostingController = hostingController
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let offsetX = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
            let offsetY = max(0, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        }
        
        @objc func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
            parent.onSingleTap?()
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

struct VideoControlsView: View {
    let player: AVPlayer
    @Binding var isPlaying: Bool
    @Binding var isMuted: Bool
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(formatTime(duration))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 4)
            
            HStack(spacing: 16) {
                Button {
                    if isPlaying { player.pause() }
                    else { player.play() }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 24)
                }
                
                CustomSlider(value: Binding(get: {
                    self.currentTime
                }, set: { newValue in
                    self.currentTime = newValue
                    self.player.seek(to: CMTime(seconds: newValue, preferredTimescale: 600))
                }), range: 0...max(duration, 0.01)) { editing in
                    self.isDragging = editing
                    if editing {
                        self.player.pause()
                    } else if self.isPlaying {
                        self.player.play()
                    }
                }
                
                Button {
                    isMuted.toggle()
                    player.isMuted = isMuted
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 24)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background {
            Rectangle()
                .fill(.black.opacity(0.4))
                .ignoresSafeArea()
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            guard !self.isDragging, let currentItem = self.player.currentItem else { return }
            let secs = currentItem.currentTime().seconds
            if !secs.isNaN { self.currentTime = secs }
            let dur = currentItem.duration.seconds
            if !dur.isNaN { self.duration = dur }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        if seconds.isNaN || seconds.isInfinite { return "00:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let percentage = max(0, min(1, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 8)
                
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(0, geometry.size.width * CGFloat(percentage)), height: 8)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    self.onEditingChanged(true)
                    let p = Double(min(max(0, drag.location.x / geometry.size.width), 1))
                    self.value = self.range.lowerBound + p * (self.range.upperBound - self.range.lowerBound)
                }
                .onEnded { _ in
                    self.onEditingChanged(false)
                }
            )
        }
        .frame(height: 24)
    }
}

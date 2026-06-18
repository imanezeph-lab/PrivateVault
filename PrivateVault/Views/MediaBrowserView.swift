import SwiftUI
import AVKit

struct MediaBrowserView: View {
    let items: [MediaItem]
    let initialItem: MediaItem?
    @Binding var selectedItem: MediaItem?
    @EnvironmentObject private var viewModel: VaultViewModel
    @State private var currentIndex: Int
    @State private var dragOffset: CGSize = .zero
    @State private var showUI: Bool = true

    init(items: [MediaItem], initialItem: MediaItem?, selectedItem: Binding<MediaItem?>) {
        self.items = items
        self.initialItem = initialItem
        self._selectedItem = selectedItem
        let idx = items.firstIndex(where: { $0.id == initialItem?.id }) ?? 0
        self._currentIndex = State(initialValue: idx)
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "photo.on.rectangle",
                        description: Text("Nothing to view here.")
                    )
                } else if viewModel.navigationMode == .swipe {
                    swipeContent
                } else {
                    scrollContent
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { selectedItem = nil }
                }

                ToolbarItem(placement: .principal) {
                    if !items.isEmpty {
                        Text("\(currentIndex + 1) of \(items.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation {
                                viewModel.navigationOrder = viewModel.navigationOrder == .newestFirst
                                    ? .oldestFirst
                                    : .newestFirst
                            }
                        } label: {
                            Image(systemName: viewModel.navigationOrder == .newestFirst
                                  ? "arrow.down.to.line"
                                  : "arrow.up.to.line")
                        }

                        Button {
                            withAnimation {
                                viewModel.navigationMode = viewModel.navigationMode == .swipe
                                    ? .scroll
                                    : .swipe
                            }
                        } label: {
                            Image(systemName: viewModel.navigationMode == .swipe
                                  ? "scroll"
                                  : "book.pages")
                        }
                    }
                }
            }
        }
        .toolbar(showUI ? .visible : .hidden, for: .navigationBar, .bottomBar)
        .offset(y: dragOffset.height)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 && abs(value.translation.height) > abs(value.translation.width) {
                        dragOffset = CGSize(width: 0, height: value.translation.height)
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 && abs(value.translation.height) > abs(value.translation.width) {
                        selectedItem = nil
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        }
    }

    private var swipeContent: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                MediaContentView(item: item, showUI: $showUI)
                    .ignoresSafeArea(edges: item.type == .file ? [] : .all)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: showUI ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private var scrollContent: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    MediaContentView(item: item, showUI: $showUI)
                        .ignoresSafeArea(edges: item.type == .file ? [] : .all)
                        .containerRelativeFrame(.vertical)
                        .onAppear { currentIndex = index }
                }
            }
        }
        .scrollTargetBehavior(.viewAligned)
    }
}

import SwiftUI
import PhotosUI

@MainActor
final class VaultViewModel: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var isGrid = true

    private let storage = FileStorageService.shared

    init() {
        loadItems()
    }

    func loadItems() {
        items = storage.loadIndex().sorted { $0.dateAdded > $1.dateAdded }
    }

    func addItem(_ item: MediaItem) {
        withAnimation {
            items.insert(item, at: 0)
        }
        storage.saveIndex(items)
    }

    func deleteItem(_ item: MediaItem) {
        withAnimation {
            items.removeAll { $0.id == item.id }
        }
        storage.deleteFile(item)
        storage.saveIndex(items)
    }

    func handlePickedPhotos(_ items: [PhotosPickerItem]) {
        for item in items {
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                let type = item.supportedContentTypes.first ?? .image
                let mediaType: MediaType
                if type == .gif { mediaType = .gif }
                else if type == .movie { mediaType = .video }
                else { mediaType = .image }

                let ext = type.preferredFilenameExtension ?? "jpg"
                if let mediaItem = FileStorageService.shared.writeData(data, ext: ext, type: mediaType) {
                    addItem(mediaItem)
                }
            }
        }
    }

    func handleDocumentPicker(urls: [URL]) {
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            let ext = url.pathExtension.lowercased()
            let mediaType: MediaType
            if ["jpg", "jpeg", "png", "heic", "heif", "webp", "bmp", "tiff"].contains(ext) {
                mediaType = .image
            } else if ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) {
                mediaType = .video
            } else if ["gif"].contains(ext) {
                mediaType = .gif
            } else if ["mp3", "wav", "aac", "flac", "ogg", "wma", "m4a", "alac", "aiff"].contains(ext) {
                mediaType = .file
            } else {
                mediaType = .file
            }

            if let item = FileStorageService.shared.copyFile(from: url, type: mediaType) {
                addItem(item)
            }
        }
    }

    func handleCameraCapture(url: URL) {
        let ext = url.pathExtension.lowercased()
        let mediaType: MediaType = ["mp4", "mov", "m4v"].contains(ext) ? .video : .image
        if let item = FileStorageService.shared.copyFile(from: url, type: mediaType) {
            addItem(item)
        }
    }
}

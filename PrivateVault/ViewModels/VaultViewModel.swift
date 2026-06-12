import SwiftUI
import PhotosUI

@MainActor
final class VaultViewModel: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var folders: [Folder] = []
    @Published var isGrid = true
    @Published var selectedFolderID: UUID?

    private let storage = FileStorageService.shared

    var filteredItems: [MediaItem] {
        if let folderID = selectedFolderID {
            items.filter { $0.folderID == folderID }
        } else {
            items
        }
    }

    var currentFolderName: String {
        guard let id = selectedFolderID,
              let folder = folders.first(where: { $0.id == id })
        else { return "All Items" }
        return folder.name
    }

    init() {
        loadAll()
    }

    func loadAll() {
        items = storage.loadIndex().sorted { $0.dateAdded > $1.dateAdded }
        folders = storage.loadFolders()
    }

    // MARK: - Items

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

    func moveItem(_ item: MediaItem, to folderID: UUID?) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].folderID = folderID
        storage.saveIndex(items)
        objectWillChange.send()
    }

    func itemsWithoutFolder() -> [MediaItem] {
        items.filter { $0.folderID == nil }
    }

    // MARK: - Folders

    func createFolder(name: String, icon: String = "folder") {
        let folder = Folder(name: name, icon: icon)
        withAnimation {
            folders.append(folder)
        }
        storage.saveFolders(folders)
    }

    func deleteFolder(_ folder: Folder) {
        for i in items.indices where items[i].folderID == folder.id {
            items[i].folderID = nil
        }
        withAnimation {
            folders.removeAll { $0.id == folder.id }
        }
        storage.saveFolders(folders)
        storage.saveIndex(items)
        if selectedFolderID == folder.id {
            selectedFolderID = nil
        }
    }

    func renameFolder(_ folder: Folder, to name: String) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].name = name
        storage.saveFolders(folders)
    }

    func folderItemCount(_ folder: Folder) -> Int {
        items.filter { $0.folderID == folder.id }.count
    }

    // MARK: - Import

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
                var mediaItem = FileStorageService.shared.writeData(data, ext: ext, type: mediaType)
                mediaItem?.folderID = selectedFolderID
                if let mediaItem {
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

            var item = FileStorageService.shared.copyFile(from: url, type: mediaType)
            item?.folderID = selectedFolderID
            if let item {
                addItem(item)
            }
        }
    }

    func handleCameraCapture(url: URL) {
        let ext = url.pathExtension.lowercased()
        let mediaType: MediaType = ["mp4", "mov", "m4v"].contains(ext) ? .video : .image
        var item = FileStorageService.shared.copyFile(from: url, type: mediaType)
        item?.folderID = selectedFolderID
        if let item {
            addItem(item)
        }
    }
}

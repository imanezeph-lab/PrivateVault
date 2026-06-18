import SwiftUI
import PhotosUI

@MainActor
final class VaultViewModel: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var folders: [Folder] = []
    @Published var isGrid = true
    @Published var selectedFolderID: UUID?
    @Published var searchText = ""
    @Published var showFavoritesOnly = false

    private let storage = FileStorageService.shared
    private let autoBackup = AutoBackupManager.shared

    private func persistAndBackup() {
        storage.saveIndex(items)
        storage.saveFolders(folders)
        autoBackup.triggerBackup(viewModel: self)
    }

    var filteredItems: [MediaItem] {
        var result = items.filter { !$0.isDeleted }

        if let folderID = selectedFolderID {
            result = result.filter { $0.folderID == folderID }
        }

        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.fileName.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result.sorted { $0.dateAdded > $1.dateAdded }
    }

    var trashedItems: [MediaItem] {
        items.filter { $0.isDeleted }.sorted { ($0.deletedDate ?? $0.dateAdded) > ($1.deletedDate ?? $1.dateAdded) }
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
        items = storage.loadIndex()
        folders = storage.loadFolders()
    }

    // MARK: - Items

    func addItem(_ item: MediaItem) {
        withAnimation {
            items.insert(item, at: 0)
        }
        persistAndBackup()
    }

    func toggleFavorite(_ item: MediaItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items[index]
        updated.isFavorite.toggle()
        withAnimation {
            items[index] = updated
        }
        persistAndBackup()
    }

    func softDeleteItem(_ item: MediaItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items[index]
        updated.isDeleted = true
        updated.deletedDate = Date()
        withAnimation {
            items[index] = updated
        }
        persistAndBackup()
    }

    func restoreItem(_ item: MediaItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items[index]
        updated.isDeleted = false
        updated.deletedDate = nil
        withAnimation {
            items[index] = updated
        }
        persistAndBackup()
    }

    func permanentlyDeleteItem(_ item: MediaItem) {
        withAnimation {
            items.removeAll { $0.id == item.id }
        }
        storage.deleteFile(item)
        persistAndBackup()
    }

    func emptyTrash() {
        let trashed = items.filter { $0.isDeleted }
        for item in trashed {
            storage.deleteFile(item)
        }
        withAnimation {
            items.removeAll { $0.isDeleted }
        }
        persistAndBackup()
    }

    func moveItem(_ item: MediaItem, to folderID: UUID?) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = items[index]
        updated.folderID = folderID
        items[index] = updated
        persistAndBackup()
    }

    // MARK: - Folders

    func createFolder(name: String, icon: String = "folder") {
        let folder = Folder(name: name, icon: icon)
        withAnimation {
            folders.append(folder)
        }
        persistAndBackup()
    }

    func deleteFolder(_ folder: Folder) {
        for i in items.indices where items[i].folderID == folder.id {
            var updated = items[i]
            updated.folderID = nil
            items[i] = updated
        }
        withAnimation {
            folders.removeAll { $0.id == folder.id }
        }
        if selectedFolderID == folder.id {
            selectedFolderID = nil
        }
        persistAndBackup()
    }

    func renameFolder(_ folder: Folder, to name: String) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].name = name
        persistAndBackup()
    }

    func folderItemCount(_ folder: Folder) -> Int {
        items.filter { $0.folderID == folder.id && !$0.isDeleted }.count
    }

    func activeItemCount() -> Int {
        items.filter { !$0.isDeleted }.count
    }

    func favoriteCount() -> Int {
        items.filter { $0.isFavorite && !$0.isDeleted }.count
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

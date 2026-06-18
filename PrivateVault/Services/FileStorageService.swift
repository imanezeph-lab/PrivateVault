import Foundation

final class FileStorageService {
    static let shared = FileStorageService()

    let directory: URL
    private let indexURL: URL
    private let foldersIndexURL: URL
    private let indexFileName = "vault_index.json"
    private let foldersFileName = "folders.json"

    private init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        directory = paths[0].appendingPathComponent("PrivateVault", isDirectory: true)
        indexURL = directory.appendingPathComponent(indexFileName)
        foldersIndexURL = directory.appendingPathComponent(foldersFileName)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func loadIndex() -> [MediaItem] {
        guard let data = try? Data(contentsOf: indexURL),
              let items = try? JSONDecoder().decode([MediaItem].self, from: data)
        else { return [] }
        return items
    }

    func saveIndex(_ items: [MediaItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    func loadFolders() -> [Folder] {
        guard let data = try? Data(contentsOf: foldersIndexURL),
              let folders = try? JSONDecoder().decode([Folder].self, from: data)
        else { return [] }
        return folders
    }

    func saveFolders(_ folders: [Folder]) {
        guard let data = try? JSONEncoder().encode(folders) else { return }
        try? data.write(to: foldersIndexURL, options: .atomic)
    }

    func copyFile(from sourceURL: URL, type: MediaType) -> MediaItem? {
        let ext = sourceURL.pathExtension
        let fileName = "\(UUID().uuidString).\(ext)"
        let destURL = directory.appendingPathComponent(fileName)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            let attrs = try FileManager.default.attributesOfItem(atPath: destURL.path)
            let fileSize = attrs[.size] as? Int64 ?? 0
            return MediaItem(fileName: fileName, type: type, fileSize: fileSize)
        } catch {
            print("FileStorageService copy error: \(error)")
            return nil
        }
    }

    func writeData(_ data: Data, ext: String, type: MediaType) -> MediaItem? {
        let fileName = "\(UUID().uuidString).\(ext)"
        let destURL = directory.appendingPathComponent(fileName)

        do {
            try data.write(to: destURL)
            return MediaItem(fileName: fileName, type: type, fileSize: Int64(data.count))
        } catch {
            print("FileStorageService write error: \(error)")
            return nil
        }
    }

    func deleteFile(_ item: MediaItem) {
        try? FileManager.default.removeItem(at: item.fileURL)
    }

}

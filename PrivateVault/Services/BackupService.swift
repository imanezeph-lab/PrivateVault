import Foundation
import CryptoKit

struct BackupEntry: Codable {
    let fileName: String
    let type: MediaType
    let dateAdded: Date
    let fileSize: Int64
    let folderID: String?
    let data: String
}

private struct BackupContainer: Codable {
    let version: Int
    let entries: [BackupEntry]
}

enum BackupError: LocalizedError {
    case encryptFailed
    case decryptFailed
    case wrongPassphrase
    case invalidFormat
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .encryptFailed: "Failed to encrypt backup"
        case .decryptFailed: "Failed to decrypt backup"
        case .wrongPassphrase: "Wrong passphrase or corrupted file"
        case .invalidFormat: "Invalid backup file format"
        case .fileNotFound(let name): "File not found: \(name)"
        }
    }
}

struct BackupService {
    static func createBackup(items: [MediaItem]) throws -> Data {
        var entries: [BackupEntry] = []

        for item in items {
            let fileURL = FileStorageService.shared.directory.appendingPathComponent(item.fileName)
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let fileData = try? Data(contentsOf: fileURL)
            else { throw BackupError.fileNotFound(item.fileName) }

            let entry = BackupEntry(
                fileName: item.fileName,
                type: item.type,
                dateAdded: item.dateAdded,
                fileSize: item.fileSize,
                folderID: item.folderID?.uuidString,
                data: fileData.base64EncodedString()
            )
            entries.append(entry)
        }

        let container = BackupContainer(version: 1, entries: entries)
        let jsonData = try JSONEncoder().encode(container)
        return jsonData
    }

    static func encryptBackup(_ data: Data, passphrase: String) throws -> Data {
        let key = deriveKey(from: passphrase)
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else { throw BackupError.encryptFailed }
        return combined
    }

    static func decryptBackup(_ data: Data, passphrase: String) throws -> Data {
        let key = deriveKey(from: passphrase)
        guard let sealedBox = try? AES.GCM.SealedBox(combined: data) else {
            throw BackupError.invalidFormat
        }
        return try AES.GCM.open(sealedBox, using: key)
    }

    static func extractEntries(from data: Data) throws -> [BackupEntry] {
        let container = try JSONDecoder().decode(BackupContainer.self, from: data)
        return container.entries
    }

    static func restoreEntries(_ entries: [BackupEntry], into viewModel: VaultViewModel) {
        for entry in entries {
            guard let fileData = Data(base64Encoded: entry.data) else { continue }
            let ext = (entry.fileName as NSString).pathExtension

            var item = FileStorageService.shared.writeData(fileData, ext: ext, type: entry.type)
            if let folderID = entry.folderID, let uuid = UUID(uuidString: folderID) {
                item?.folderID = uuid
            }
            if let item {
                viewModel.addItem(item)
            }
        }
    }

    private static func deriveKey(from passphrase: String) -> SymmetricKey {
        let data = Data(passphrase.utf8)
        let hash = SHA256.hash(data: data)
        return SymmetricKey(data: hash)
    }
}

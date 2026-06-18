import Foundation
import SwiftUI

@MainActor
final class AutoBackupManager: ObservableObject {
    static let shared = AutoBackupManager()

    @Published var lastBackupDate: Date?
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "auto_backup_enabled") }
    }
    @Published var hasExternalLocation: Bool = false
    @Published var lastError: String?

    private let storage = FileStorageService.shared
    private let backupDirName = "VaultBackups"
    private let maxLocalBackups = 20
    private let passphraseKey = "auto_backup_passphrase"
    private let bookmarkKey = "auto_backup_external_bookmark"
    private let lastBackupKey = "auto_backup_last_date"

    private var passphrase: String = ""

    private init() {
        if UserDefaults.standard.object(forKey: "auto_backup_enabled") == nil {
            UserDefaults.standard.set(true, forKey: "auto_backup_enabled")
        }
        isEnabled = UserDefaults.standard.bool(forKey: "auto_backup_enabled")
        if let ts = UserDefaults.standard.object(forKey: lastBackupKey) as? TimeInterval {
            lastBackupDate = Date(timeIntervalSince1970: ts)
        }
        hasExternalLocation = UserDefaults.standard.data(forKey: bookmarkKey) != nil
        loadOrCreatePassphrase()
    }

    private func loadOrCreatePassphrase() {
        if let stored = UserDefaults.standard.string(forKey: passphraseKey) {
            passphrase = stored
        } else {
            passphrase = generatePassphrase()
            UserDefaults.standard.set(passphrase, forKey: passphraseKey)
        }
    }

    var backupPassphrase: String { passphrase }

    var localBackupDir: URL {
        storage.directory.appendingPathComponent(backupDirName, isDirectory: true)
    }

    func setupExternalLocation(from url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            hasExternalLocation = true
            return true
        } catch {
            lastError = "Failed to save location: \(error.localizedDescription)"
            return false
        }
    }

    func clearExternalLocation() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        hasExternalLocation = false
    }

    private var backupTask: Task<Void, Never>?

    func triggerBackup(viewModel: VaultViewModel) {
        guard isEnabled else { return }

        backupTask?.cancel()
        backupTask = Task { [weak self, weak viewModel] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self, let viewModel, !Task.isCancelled else { return }

            do {
                let allItems = viewModel.items
                let jsonData = try BackupService.createBackup(items: allItems)
                let encrypted = try BackupService.encryptBackup(jsonData, passphrase: passphrase)

                try? FileManager.default.createDirectory(at: localBackupDir, withIntermediateDirectories: true)

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let filename = "AutoBackup_\(formatter.string(from: Date())).vault"
                let localURL = localBackupDir.appendingPathComponent(filename)
                try encrypted.write(to: localURL, options: .atomic)

                cleanupOldBackups()

                if hasExternalLocation, let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
                    writeToExternal(encrypted, bookmarkData: bookmarkData)
                }

                let now = Date()
                lastBackupDate = now
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastBackupKey)
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func writeToExternal(_ data: Data, bookmarkData: Data) {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale),
              url.startAccessingSecurityScopedResource()
        else {
            if isStale {
                clearExternalLocation()
                lastError = "Backup location is no longer available. Please set it again."
            }
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "PrivateVault_\(formatter.string(from: Date())).vault"
        let destURL = url.appendingPathComponent(filename)

        try? data.write(to: destURL, options: .atomic)
    }

    private func cleanupOldBackups() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: localBackupDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else { return }
        let vaultFiles = files.filter { $0.pathExtension == "vault" }.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return da > db
        }
        if vaultFiles.count > maxLocalBackups {
            for file in vaultFiles[maxLocalBackups...] {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private func generatePassphrase() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
        return String((0..<32).compactMap { _ in chars.randomElement() })
    }
}

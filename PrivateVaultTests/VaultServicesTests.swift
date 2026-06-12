import XCTest
@testable import PrivateVault

final class VaultServicesTests: XCTestCase {

    func testMediaItemInitialization() {
        let item = MediaItem(fileName: "test.jpg", type: .image, fileSize: 1024)
        XCTAssertEqual(item.fileName, "test.jpg")
        XCTAssertEqual(item.type, .image)
        XCTAssertEqual(item.fileSize, 1024)
        XCTAssertFalse(item.isFavorite)
        XCTAssertFalse(item.isDeleted)
        XCTAssertNil(item.deletedDate)
        XCTAssertNil(item.folderID)
    }

    func testMediaItemFavoriteToggle() {
        var item = MediaItem(fileName: "test.jpg", type: .image)
        item.isFavorite = true
        XCTAssertTrue(item.isFavorite)
        item.isFavorite = false
        XCTAssertFalse(item.isFavorite)
    }

    func testMediaItemSoftDelete() {
        var item = MediaItem(fileName: "test.jpg", type: .image)
        item.isDeleted = true
        item.deletedDate = Date()
        XCTAssertTrue(item.isDeleted)
        XCTAssertNotNil(item.deletedDate)
    }

    func testMediaTypeIcons() {
        XCTAssertEqual(MediaType.image.icon, "photo")
        XCTAssertEqual(MediaType.video.icon, "video")
        XCTAssertEqual(MediaType.gif.icon, "play.rectangle")
        XCTAssertEqual(MediaType.file.icon, "doc")
    }

    func testFolderInitialization() {
        let folder = Folder(name: "Test Folder")
        XCTAssertEqual(folder.name, "Test Folder")
        XCTAssertEqual(folder.icon, "folder")
    }

    func testFolderRename() {
        var folder = Folder(name: "Old Name")
        folder.name = "New Name"
        XCTAssertEqual(folder.name, "New Name")
    }

    func testByteCountFormatter() {
        let item = MediaItem(fileName: "test.jpg", type: .image, fileSize: 1_048_576)
        let formatted = item.formattedSize
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("MB") || formatted.contains("KB"))
    }

    func testBackupEntryRoundTrip() throws {
        let original = BackupEntry(
            fileName: "photo.jpg",
            type: .image,
            dateAdded: Date(),
            fileSize: 1234,
            folderID: nil,
            isFavorite: true,
            isDeleted: false,
            deletedDate: nil,
            data: "dGVzdA=="
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BackupEntry.self, from: data)

        XCTAssertEqual(original.fileName, decoded.fileName)
        XCTAssertEqual(original.type, decoded.type)
        XCTAssertEqual(original.isFavorite, decoded.isFavorite)
        XCTAssertEqual(original.fileSize, decoded.fileSize)
    }

    func testAppThemeDefaults() {
        let manager = ThemeManager()
        XCTAssertEqual(manager.theme, .system)
    }

    func testAppThemeCases() {
        XCTAssertEqual(AppTheme.allCases.count, 3)
        XCTAssertTrue(AppTheme.allCases.contains(.system))
        XCTAssertTrue(AppTheme.allCases.contains(.light))
        XCTAssertTrue(AppTheme.allCases.contains(.dark))
    }

    func testMediaItemEquality() {
        let id = UUID()
        let a = MediaItem(id: id, fileName: "a.jpg", type: .image)
        let b = MediaItem(id: id, fileName: "a.jpg", type: .image)
        XCTAssertEqual(a, b)
    }

    func testMediaItemInequality() {
        let a = MediaItem(fileName: "a.jpg", type: .image)
        let b = MediaItem(fileName: "b.jpg", type: .video)
        XCTAssertNotEqual(a, b)
    }
}

import XCTest
@testable import PrivateVault

@MainActor
final class VaultViewModelTests: XCTestCase {

    var viewModel: VaultViewModel!

    override func setUp() {
        super.setUp()
        viewModel = VaultViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertTrue(viewModel.folders.isEmpty)
        XCTAssertTrue(viewModel.isGrid)
        XCTAssertNil(viewModel.selectedFolderID)
        XCTAssertTrue(viewModel.searchText.isEmpty)
        XCTAssertFalse(viewModel.showFavoritesOnly)
    }

    func testAddItem() {
        let item = MediaItem(fileName: "test.jpg", type: .image)
        viewModel.addItem(item)
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.activeItemCount(), 1)
    }

    func testToggleFavorite() {
        let item = MediaItem(fileName: "test.jpg", type: .image)
        viewModel.addItem(item)
        viewModel.toggleFavorite(item)
        XCTAssertTrue(viewModel.filteredItems.first?.isFavorite == true)
        viewModel.toggleFavorite(item)
        XCTAssertTrue(viewModel.filteredItems.first?.isFavorite == false)
    }

    func testSoftDeleteAndRestore() {
        let item = MediaItem(fileName: "test.jpg", type: .image)
        viewModel.addItem(item)
        XCTAssertEqual(viewModel.filteredItems.count, 1)

        viewModel.softDeleteItem(item)
        XCTAssertEqual(viewModel.filteredItems.count, 0)
        XCTAssertEqual(viewModel.trashedItems.count, 1)

        viewModel.restoreItem(item)
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.trashedItems.count, 0)
    }

    func testSearchFilter() {
        let item1 = MediaItem(fileName: "vacation.jpg", type: .image)
        let item2 = MediaItem(fileName: "document.pdf", type: .file)
        viewModel.addItem(item1)
        viewModel.addItem(item2)

        viewModel.searchText = "vacation"
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertEqual(viewModel.filteredItems.first?.fileName, "vacation.jpg")

        viewModel.searchText = ""
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }

    func testFavoritesFilter() {
        let item1 = MediaItem(fileName: "a.jpg", type: .image)
        let item2 = MediaItem(fileName: "b.jpg", type: .image)
        viewModel.addItem(item1)
        viewModel.addItem(item2)

        viewModel.toggleFavorite(item1)
        viewModel.showFavoritesOnly = true
        XCTAssertEqual(viewModel.filteredItems.count, 1)
        XCTAssertTrue(viewModel.filteredItems.first?.isFavorite == true)

        viewModel.showFavoritesOnly = false
        XCTAssertEqual(viewModel.filteredItems.count, 2)
    }

    func testFolderOperations() {
        viewModel.createFolder(name: "Test Folder")
        XCTAssertEqual(viewModel.folders.count, 1)
        XCTAssertEqual(viewModel.folders.first?.name, "Test Folder")

        let folder = viewModel.folders[0]
        viewModel.renameFolder(folder, to: "Renamed")
        XCTAssertEqual(viewModel.folders.first?.name, "Renamed")

        viewModel.deleteFolder(folder)
        XCTAssertTrue(viewModel.folders.isEmpty)
    }

    func testMoveItemToFolder() {
        let folder = Folder(name: "Folder")
        viewModel.folders.append(folder)

        let item = MediaItem(fileName: "test.jpg", type: .image)
        viewModel.addItem(item)

        viewModel.moveItem(item, to: folder.id)
        viewModel.selectedFolderID = folder.id
        XCTAssertEqual(viewModel.filteredItems.count, 1)

        viewModel.moveItem(item, to: nil)
        viewModel.selectedFolderID = nil
        XCTAssertEqual(viewModel.filteredItems.count, 1)
    }

    func testItemCounts() {
        let item1 = MediaItem(fileName: "a.jpg", type: .image)
        let item2 = MediaItem(fileName: "b.jpg", type: .image)
        viewModel.addItem(item1)
        viewModel.addItem(item2)

        XCTAssertEqual(viewModel.activeItemCount(), 2)
        XCTAssertEqual(viewModel.favoriteCount(), 0)

        viewModel.toggleFavorite(item1)
        XCTAssertEqual(viewModel.favoriteCount(), 1)
    }

    func testEmptyTrash() {
        let item = MediaItem(fileName: "test.jpg", type: .image)
        viewModel.addItem(item)
        viewModel.softDeleteItem(item)
        XCTAssertEqual(viewModel.trashedItems.count, 1)

        viewModel.emptyTrash()
        XCTAssertEqual(viewModel.trashedItems.count, 0)
        XCTAssertTrue(viewModel.items.isEmpty)
    }
}

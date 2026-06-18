import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: VaultViewModel
    @State private var showingImport = false
    @State private var selectedItem: MediaItem?

    var body: some View {
        NavigationStack {
            FolderListView(selectedItem: $selectedItem, showingImport: $showingImport)
                .sheet(isPresented: $showingImport) {
                    ImportView()
                        .environmentObject(viewModel)
                }
        }
        .fullScreenCover(item: $selectedItem) { item in
            MediaBrowserView(
                items: viewModel.filteredItems,
                initialItem: item,
                selectedItem: $selectedItem
            )
            .environmentObject(viewModel)
        }
    }
}

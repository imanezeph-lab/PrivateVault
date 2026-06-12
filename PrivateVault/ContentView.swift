import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: VaultViewModel
    @State private var showingImport = false
    @State private var selectedItem: MediaItem?

    var body: some View {
        NavigationStack {
            FolderListView(selectedItem: $selectedItem, showingImport: $showingImport)
                .fullScreenCover(item: $selectedItem) { item in
                    DetailView(item: item)
                        .environmentObject(viewModel)
                }
                .sheet(isPresented: $showingImport) {
                    ImportView()
                        .environmentObject(viewModel)
                }
        }
    }
}

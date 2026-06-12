import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: VaultViewModel
    @State private var showingImport = false
    @State private var selectedItem: MediaItem?

    var body: some View {
        NavigationStack {
            GalleryView(selectedItem: $selectedItem)
                .navigationTitle("Private Vault")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation { viewModel.isGrid.toggle() }
                        } label: {
                            Image(systemName: viewModel.isGrid
                                  ? "list.bullet"
                                  : "square.grid.2x2")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingImport = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
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

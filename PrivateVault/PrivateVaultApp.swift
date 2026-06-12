import SwiftUI

@main
struct PrivateVaultApp: App {
    @StateObject private var authService = BiometricAuthService()
    @StateObject private var viewModel = VaultViewModel()

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView()
                    .environmentObject(viewModel)
            } else {
                LockView(authService: authService)
            }
        }
    }
}

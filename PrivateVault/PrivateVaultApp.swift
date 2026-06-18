import SwiftUI

@main
struct PrivateVaultApp: App {
    @StateObject private var authService = BiometricAuthService()
    @StateObject private var viewModel = VaultViewModel()
    @StateObject private var themeManager = ThemeManager()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "has_launched")

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    ContentView()
                        .environmentObject(viewModel)
                        .environmentObject(themeManager)
                        .preferredColorScheme(themeManager.theme.colorScheme)
                        .sheet(isPresented: $showOnboarding) {
                            OnboardingView(isShowing: $showOnboarding)
                                .onDisappear {
                                    UserDefaults.standard.set(true, forKey: "has_launched")
                                }
                                .preferredColorScheme(themeManager.theme.colorScheme)
                        }
                } else {
                    LockView(authService: authService)
                        .preferredColorScheme(themeManager.theme.colorScheme)
                }
            }
        }
    }
}

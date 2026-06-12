import SwiftUI

struct OnboardingView: View {
    @Binding var isShowing: Bool

    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, detail: String)] = [
        ("lock.shield.fill", "Welcome to Private Vault",
         "Your personal, encrypted vault for photos, videos, and files. Everything stays on your device — nothing is shared."),
        ("faceid", "Biometric Lock",
         "Face ID or Touch ID keeps your vault secure. You can also set a passcode as a backup."),
        ("photo.on.rectangle", "Import Anywhere",
         "Import from your photo library, files app, or camera. All media is copied into the vault — the originals are untouched."),
        ("folder.fill", "Stay Organized",
         "Create folders, mark favorites, and search through your items. Keep everything neat and easy to find."),
        ("square.and.arrow.up", "Encrypted Backups",
         "Export an AES-256 encrypted backup anytime. Restore to any device with your passphrase."),
    ]

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    pageView(index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    isShowing = false
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func pageView(_ index: Int) -> some View {
        let page = pages[index]
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: page.icon)
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text(page.title)
                .font(.title2).bold()
                .multilineTextAlignment(.center)
            Text(page.detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding()
    }
}

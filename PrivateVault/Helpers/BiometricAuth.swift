import LocalAuthentication
import SwiftUI

@MainActor
final class BiometricAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var showPasscode = false
    @Published var isSettingPasscode = false

    private let passcodeKey = "vault_passcode"

    var storedPasscode: String {
        UserDefaults.standard.string(forKey: passcodeKey) ?? ""
    }

    func authenticate() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            showPasscode = true
            isSettingPasscode = storedPasscode.isEmpty
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Private Vault") { success, _ in
            Task { @MainActor in
                if success {
                    self.isAuthenticated = true
                } else {
                    self.showPasscode = true
                    self.isSettingPasscode = self.storedPasscode.isEmpty
                }
            }
        }
    }

    func verifyPasscode(_ code: String) -> Bool {
        guard code == storedPasscode else { return false }
        isAuthenticated = true
        showPasscode = false
        return true
    }

    func setPasscode(_ code: String) {
        UserDefaults.standard.set(code, forKey: passcodeKey)
        isAuthenticated = true
        isSettingPasscode = false
        showPasscode = false
    }
}

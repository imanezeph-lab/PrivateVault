import SwiftUI

struct LockView: View {
    @ObservedObject var authService: BiometricAuthService
    @State private var passcodeInput = ""
    @State private var newPasscode = ""
    @State private var confirmPasscode = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Private Vault")
                .font(.title2).bold()

            if authService.showPasscode {
                if authService.isSettingPasscode {
                    setupView
                } else {
                    unlockView
                }
            } else {
                VStack(spacing: 16) {
                    Button {
                        authService.authenticate()
                    } label: {
                        Label("Unlock with Face ID / Touch ID", systemImage: "faceid")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if !authService.storedPasscode.isEmpty {
                        Button("Use Passcode") {
                            authService.showPasscode = true
                        }
                    }
                }
                .padding(.horizontal, 40)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            authService.authenticate()
        }
    }

    private var unlockView: some View {
        VStack(spacing: 16) {
            Text("Enter Passcode")
                .font(.headline)
                .foregroundStyle(.secondary)

            SecureField("Passcode", text: $passcodeInput)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(maxWidth: 220)
                .multilineTextAlignment(.center)

            Button("Unlock") {
                if authService.verifyPasscode(passcodeInput) {
                    passcodeInput = ""
                } else {
                    passcodeInput = ""
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(passcodeInput.isEmpty)
        }
    }

    private var setupView: some View {
        VStack(spacing: 16) {
            Text("Create a Passcode")
                .font(.headline)
                .foregroundStyle(.secondary)

            SecureField("New passcode", text: $newPasscode)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(maxWidth: 220)
                .multilineTextAlignment(.center)

            SecureField("Confirm passcode", text: $confirmPasscode)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .frame(maxWidth: 220)
                .multilineTextAlignment(.center)

            Button("Set Passcode") {
                guard !newPasscode.isEmpty, newPasscode == confirmPasscode else { return }
                authService.setPasscode(newPasscode)
            }
            .buttonStyle(.borderedProminent)
            .disabled(newPasscode.isEmpty || newPasscode != confirmPasscode)
        }
    }
}

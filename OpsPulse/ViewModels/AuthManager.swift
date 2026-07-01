//
//  OpsPulseApp.swift
//  OpsPulse
//
//  Created by Randall Ridley on 7/1/26.
//

import Foundation
import LocalAuthentication

@MainActor
final class AuthManager: ObservableObject {
    @Published var isUnlocked: Bool = false
    @Published var lastErrorMessage: String?

    private let keychain = KeychainStore()

    private enum Keys {
        static let authToken = "auth_token"
    }

    func bootstrap() {
        // For demo purposes we store a token once so APIClient can demonstrate Keychain usage.
        // In a real app, this would happen after a login/OAuth flow.
        if (try? keychain.getString(forKey: Keys.authToken)) == nil {
            try? keychain.setString("demo-token", forKey: Keys.authToken)
        }
    }

    func unlockWithBiometrics() async {
        lastErrorMessage = nil

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        let canEvaluateBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        let policy: LAPolicy
        if canEvaluateBiometrics {
            policy = .deviceOwnerAuthenticationWithBiometrics
        } else {
            var passcodeError: NSError?
            let canEvaluatePasscode = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &passcodeError)
            if canEvaluatePasscode {
                policy = .deviceOwnerAuthentication
            } else {
                if let passcodeError {
                    lastErrorMessage = passcodeError.localizedDescription
                } else if let error {
                    lastErrorMessage = error.localizedDescription
                } else {
                    lastErrorMessage = "Authentication is not available on this device."
                }
                isUnlocked = false
                return
            }
        }

        do {
            let ok = try await context.evaluatePolicy(
                policy,
                localizedReason: "Authenticate to unlock OpsPulse"
            )
            isUnlocked = ok
            if !ok {
                lastErrorMessage = "Authentication failed"
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            isUnlocked = false
        }
    }

    func lock() {
        isUnlocked = false
    }

    func authToken() -> String? {
        try? keychain.getString(forKey: Keys.authToken)
    }
}

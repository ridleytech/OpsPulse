//
//  OpsPulseApp.swift
//  OpsPulse
//
//  Created by Randall Ridley on 7/1/26.
//

import SwiftUI

struct LockGateView: View {
    @StateObject private var authManager = AuthManager()

    var body: some View {
        Group {
            if authManager.isUnlocked {
                AssetsView()
                    .environmentObject(authManager)
            } else {
                VStack(spacing: 16) {
                    AppHeaderView()

                    Text("OpsPulse")
                        .font(.largeTitle)
                        .fontWeight(.semibold)

                    if let lastErrorMessage = authManager.lastErrorMessage {
                        Text(lastErrorMessage)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Unlock") {
                        Task { await authManager.unlockWithBiometrics() }
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer(minLength: 0)
                }
                .padding(0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .task {
                    authManager.bootstrap()
                    await authManager.unlockWithBiometrics()
                }
            }
        }
    }
}

#Preview {
    LockGateView()
}

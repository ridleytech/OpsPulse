//
//  OpsPulseApp.swift
//  OpsPulse
//
//  Created by Randall Ridley on 7/1/26.
//

import SwiftUI
import SwiftData

@main
struct OpsPulseApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AssetEntity.self,
            EventEntity.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            LockGateView()
        }
        .modelContainer(sharedModelContainer)
    }
}

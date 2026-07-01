//
//  OpsPulseApp.swift
//  OpsPulse
//
//  Created by Randall Ridley on 7/1/26.
//

import Charts
import SwiftData
import SwiftUI
import Foundation

#Preview {
    AssetsView()
        .modelContainer(makePreviewContainer())
}

#Preview {
    NavigationStack {
        AssetDetailView(assetId: "A-100")
    }
    .modelContainer(makePreviewContainer())
}

#Preview {
    let event = EventEntity(id: "E-Preview", assetId: "A-100", timestamp: Date(), severity: "medium", message: "Valve inspection scheduled")
    return EventRow(event: event)
        .modelContainer(makePreviewContainer())
}

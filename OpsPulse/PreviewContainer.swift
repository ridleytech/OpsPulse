import Foundation
import SwiftData

func makePreviewContainer() -> ModelContainer {
    let schema = Schema([
        AssetEntity.self,
        EventEntity.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
    let context = ModelContext(container)

    let assetId = "A-100"
    context.insert(AssetEntity(id: assetId, name: "EOG Well 100", type: "well", location: "Permian", status: "online", updatedAt: Date()))
    context.insert(AssetEntity(id: "C-22", name: "Compressor 22", type: "compressor", location: "Eagle Ford", status: "maintenance", updatedAt: Date()))

    context.insert(EventEntity(id: "E-1", assetId: assetId, timestamp: Date().addingTimeInterval(-300), severity: "high", message: "Pressure spike detected"))
    context.insert(EventEntity(id: "E-2", assetId: assetId, timestamp: Date().addingTimeInterval(-120), severity: "low", message: "Flow rate returned to normal"))

    try? context.save()
    return container
}

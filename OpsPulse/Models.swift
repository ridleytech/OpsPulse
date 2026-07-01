import Foundation
import SwiftData

struct AssetDTO: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let location: String
    let status: String
}

struct TelemetryDTO: Codable {
    let assetId: String
    let timestamp: String
    let pressure: Double
    let flow: Double
    let temperature: Double
}

struct EventDTO: Codable, Identifiable {
    let id: String
    let assetId: String
    let timestamp: String
    let severity: String
    let message: String
}

@Model
final class AssetEntity {
    @Attribute(.unique) var id: String
    var name: String
    var type: String
    var location: String
    var status: String
    var updatedAt: Date

    init(id: String, name: String, type: String, location: String, status: String, updatedAt: Date) {
        self.id = id
        self.name = name
        self.type = type
        self.location = location
        self.status = status
        self.updatedAt = updatedAt
    }

    static func upsert(from dto: AssetDTO, in context: ModelContext) {
        let descriptor = FetchDescriptor<AssetEntity>(predicate: #Predicate { $0.id == dto.id })
        let existing = (try? context.fetch(descriptor))?.first
        if let existing {
            existing.name = dto.name
            existing.type = dto.type
            existing.location = dto.location
            existing.status = dto.status
            existing.updatedAt = Date()
        } else {
            context.insert(AssetEntity(id: dto.id, name: dto.name, type: dto.type, location: dto.location, status: dto.status, updatedAt: Date()))
        }
    }
}

@Model
final class EventEntity {
    @Attribute(.unique) var id: String
    var assetId: String
    var timestamp: Date
    var severity: String
    var message: String
    var acknowledgedAt: Date?
    var acknowledgedNote: String?

    init(id: String, assetId: String, timestamp: Date, severity: String, message: String, acknowledgedAt: Date? = nil, acknowledgedNote: String? = nil) {
        self.id = id
        self.assetId = assetId
        self.timestamp = timestamp
        self.severity = severity
        self.message = message
        self.acknowledgedAt = acknowledgedAt
        self.acknowledgedNote = acknowledgedNote
    }

    var isAcknowledged: Bool {
        acknowledgedAt != nil
    }
}

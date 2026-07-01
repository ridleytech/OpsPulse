import SwiftData
import SwiftUI

@MainActor
final class AssetDetailViewModel: ObservableObject {
    @Published var points: [TelemetryPoint] = []
    @Published var lastTelemetry: TelemetryDTO?

    private let stompClient: STOMPClient
    private var isConnected = false

    init(stompClient: STOMPClient = STOMPClient()) {
        self.stompClient = stompClient
    }

    func start(assetId: String, modelContext: ModelContext) {
        if !isConnected {
            stompClient.connect()
            isConnected = true
        }

        let telemetryDest = "/topic/telemetry.\(assetId)"
        let eventsDest = "/topic/events.\(assetId)"

        do {
            try stompClient.subscribe(destination: telemetryDest) { [weak self] _, data in
                guard let self else { return }
                guard let dto = try? JSONDecoder().decode(TelemetryDTO.self, from: data) else { return }

                Task { @MainActor in
                    self.lastTelemetry = dto
                    let date = ISO8601DateFormatter().date(from: dto.timestamp) ?? Date()
                    self.points.append(TelemetryPoint(date: date, pressure: dto.pressure, flow: dto.flow, temperature: dto.temperature))
                    if self.points.count > 120 {
                        self.points.removeFirst(self.points.count - 120)
                    }
                }
            }

            try stompClient.subscribe(destination: eventsDest) { _, data in
                guard let dto = try? JSONDecoder().decode(EventDTO.self, from: data) else { return }
                let date = ISO8601DateFormatter().date(from: dto.timestamp) ?? Date()

                Task { @MainActor in
                    let descriptor = FetchDescriptor<EventEntity>(predicate: #Predicate { $0.id == dto.id })
                    let existing = (try? modelContext.fetch(descriptor))?.first
                    if existing == nil {
                        modelContext.insert(EventEntity(id: dto.id, assetId: dto.assetId, timestamp: date, severity: dto.severity, message: dto.message))
                        try? modelContext.save()
                    }
                }
            }
        } catch {}
    }
}

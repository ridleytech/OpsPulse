//
//  OpsPulseApp.swift
//  OpsPulse
//
//  Created by Randall Ridley on 7/1/26.
//

import Charts
import SwiftData
import SwiftUI

@MainActor
final class AssetsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func refresh(modelContext: ModelContext) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let assets = try await apiClient.fetchAssets()
            for asset in assets {
                AssetEntity.upsert(from: asset, in: modelContext)
            }
            try modelContext.save()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}

struct AssetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssetEntity.name) private var assets: [AssetEntity]

    @StateObject private var viewModel = AssetsViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeaderView {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Button {
                            Task { await viewModel.refresh(modelContext: modelContext) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(Color.white)
                        }
                    }
                }

                List {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }

                    ForEach(assets) { asset in
                        NavigationLink(value: asset.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(asset.name)
                                    .font(.headline)
                                Text("\(asset.type.uppercased()) • \(asset.location)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: String.self) { assetId in
                AssetDetailView(assetId: assetId)
            }
            .task {
                if assets.isEmpty {
                    await viewModel.refresh(modelContext: modelContext)
                }
            }
        }
    }
}

struct TelemetryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let pressure: Double
    let flow: Double
    let temperature: Double
}

enum TelemetrySeries: String, CaseIterable, Identifiable {
    case pressure = "Pressure"
    case flow = "Flow"
    case temperature = "Temp"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .pressure: return Color("BrandBlue")
        case .flow: return Color("BrandGray")
        case .temperature: return Color("BrandRed")
        }
    }
}

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

struct AssetDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let assetId: String

    @Query private var assetMatches: [AssetEntity]
    @Query private var events: [EventEntity]

    @StateObject private var viewModel = AssetDetailViewModel()
    @State private var selectedSeries: TelemetrySeries = .pressure

    init(assetId: String) {
        self.assetId = assetId
        _assetMatches = Query(filter: #Predicate { $0.id == assetId })
        _events = Query(filter: #Predicate { $0.assetId == assetId }, sort: [SortDescriptor(\EventEntity.timestamp, order: .reverse)])
    }

    var asset: AssetEntity? { assetMatches.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let asset {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(asset.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("\(asset.type.uppercased()) • \(asset.location) • \(asset.status)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(assetId)
                        .font(.title2)
                }

                if let t = viewModel.lastTelemetry {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            Text("Pressure")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f", t.pressure))
                                .font(.headline)
                        }
                        VStack(alignment: .leading) {
                            Text("Flow")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f", t.flow))
                                .font(.headline)
                        }
                        VStack(alignment: .leading) {
                            Text("Temp")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f", t.temperature))
                                .font(.headline)
                        }
                        Spacer()
                    }
                }

                VStack(alignment: .leading) {
                    Text("Live Telemetry")
                        .font(.headline)

                    Picker("Series", selection: $selectedSeries) {
                        ForEach(TelemetrySeries.allCases) { series in
                            Text(series.rawValue).tag(series)
                        }
                    }
                    .pickerStyle(.segmented)

                    Chart(viewModel.points) { p in
                        switch selectedSeries {
                        case .pressure:
                            LineMark(
                                x: .value("Time", p.date),
                                y: .value("Pressure", p.pressure)
                            )
                            .foregroundStyle(selectedSeries.color)
                        case .flow:
                            LineMark(
                                x: .value("Time", p.date),
                                y: .value("Flow", p.flow)
                            )
                            .foregroundStyle(selectedSeries.color)
                        case .temperature:
                            LineMark(
                                x: .value("Time", p.date),
                                y: .value("Temp", p.temperature)
                            )
                            .foregroundStyle(selectedSeries.color)
                        }
                    }
                    .frame(height: 200)
                }

                VStack(alignment: .leading) {
                    Text("Events")
                        .font(.headline)

                    if events.isEmpty {
                        Text("No events yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(events) { event in
                            EventRow(event: event)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(asset?.id ?? assetId)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.start(assetId: assetId, modelContext: modelContext)
        }
    }
}

struct EventRow: View {
    @Environment(\.modelContext) private var modelContext

    let event: EventEntity

    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.severity.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text(event.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(event.message)

            if event.isAcknowledged {
                Text("Acknowledged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let acknowledgedNote = event.acknowledgedNote, !acknowledgedNote.isEmpty {
                    Text(acknowledgedNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    TextField("Ack note", text: $note)
                        .textFieldStyle(.roundedBorder)

                    Button("Ack") {
                        event.acknowledgedAt = Date()
                        event.acknowledgedNote = note
                        try? modelContext.save()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private func makePreviewContainer() -> ModelContainer {
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

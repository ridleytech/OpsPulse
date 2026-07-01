import Charts
import SwiftData
import SwiftUI

struct AssetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
            .padding(.horizontal)
            .padding(.bottom)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                AppHeaderView()

                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .foregroundStyle(Color("BrandGray"))

                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.start(assetId: assetId, modelContext: modelContext)
        }
    }
}

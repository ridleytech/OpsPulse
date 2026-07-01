import SwiftData
import SwiftUI

struct AssetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssetEntity.name) private var assets: [AssetEntity]

    @StateObject private var viewModel = AssetsViewModel()

    var body: some View {
        NavigationStack {
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
            .safeAreaInset(edge: .top, spacing: 0) {
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

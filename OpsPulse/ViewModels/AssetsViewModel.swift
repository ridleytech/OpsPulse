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

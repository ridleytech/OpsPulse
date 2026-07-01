import SwiftUI

struct AppHeaderView<Trailing: View>: View {
    private let trailing: Trailing

    init(@ViewBuilder trailing: () -> Trailing) {
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("eog-logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 50)
                .foregroundStyle(Color.white)
                .accessibilityLabel("EOG Resources")

            Spacer(minLength: 0)

            trailing
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color("BrandRed"))
        .ignoresSafeArea(edges: .top)
    }
}

extension AppHeaderView where Trailing == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}

#Preview {
    AppHeaderView()
}

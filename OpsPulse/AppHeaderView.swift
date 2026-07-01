import SwiftUI

struct AppHeaderView<Trailing: View>: View {
    private let trailing: Trailing

    init(@ViewBuilder trailing: () -> Trailing) {
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Image("eog-logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 50)
                .foregroundStyle(Color.white)
                .accessibilityLabel("EOG Resources")

            HStack {
                Spacer(minLength: 0)
                trailing
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color("BrandRed"))
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

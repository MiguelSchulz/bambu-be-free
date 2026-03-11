import SFSafeSymbols
import SwiftUI

struct ControlCard<Content: View>: View {
    let title: String
    let systemSymbol: SFSymbol
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemSymbol: systemSymbol)
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

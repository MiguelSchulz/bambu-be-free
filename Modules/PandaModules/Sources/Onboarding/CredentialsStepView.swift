import NavigatorUI
import PandaUI
import SFSafeSymbols
import SwiftUI

struct CredentialsStepView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.navigator) private var navigator

    var body: some View {
        SetupStepLayout(step: .credentials) {
            if let next = viewModel.destination(after: .credentials) {
                navigator.navigate(to: next)
            }
        } content: {
            VStack(spacing: 12) {
                credentialCard(
                    icon: .network,
                    title: "IP Address",
                    description: "Found under **Settings > WLAN** on your printer's touchscreen.",
                    example: "192.168.1.100"
                )

                credentialCard(
                    icon: .lockShield,
                    title: "Access Code",
                    description: "Displayed under **LAN Only Mode** in your printer's network settings.",
                    example: "12345678"
                )

                if viewModel.serialRequired {
                    credentialCard(
                        icon: .number,
                        title: "Serial Number",
                        description: "Found on the **Device** tab in your printer's settings.",
                        example: "01S00A000000"
                    )
                }
            }
        }
        .navigationTitle("Credentials")
    }

    private func credentialCard(
        icon: SFSymbol,
        title: LocalizedStringResource,
        description: LocalizedStringResource,
        example: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemSymbol: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(example)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }
}

#Preview {
    CredentialsStepView()
        .environment(OnboardingViewModel())
}

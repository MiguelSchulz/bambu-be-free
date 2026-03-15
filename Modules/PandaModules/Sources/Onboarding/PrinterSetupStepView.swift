import NavigatorUI
import PandaUI
import SFSafeSymbols
import SwiftUI

struct PrinterSetupStepView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.navigator) private var navigator

    private let lanModeURL = URL(string: "https://wiki.bambulab.com/en/knowledge-sharing/enable-lan-mode")!
    private let devModeURL = URL(string: "https://wiki.bambulab.com/en/knowledge-sharing/enable-developer-mode")!

    var body: some View {
        SetupStepLayout(step: .printerSetup) {
            if let next = viewModel.destination(after: .printerSetup) {
                navigator.navigate(to: next)
            }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, text: "On your printer's touchscreen, tap **Settings**")
                InstructionRow(number: 2, text: "Navigate to **WLAN** (or Network Settings)")
                InstructionRow(number: 3, text: "Find **LAN Only Mode** and turn it **ON**")
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))

            Link(destination: lanModeURL) {
                Label("LAN Mode on Bambu Wiki", systemSymbol: .safari)
            }
            .font(.subheadline)

            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 4, text: "Scroll down and find **Developer Mode**")
                InstructionRow(number: 5, text: "Read the notice, check the box and tap **Enable**")
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))

            Link(destination: devModeURL) {
                Label("Developer Mode on Bambu Wiki", systemSymbol: .safari)
            }
            .font(.subheadline)

            Text("Developer Mode disables cloud authentication so third-party apps can connect directly.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("Printer Setup")
    }
}

#Preview {
    PrinterSetupStepView()
        .environment(OnboardingViewModel())
}

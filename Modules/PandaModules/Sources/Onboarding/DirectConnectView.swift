import PandaModels
import SFSafeSymbols
import SwiftUI

struct DirectConnectView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @FocusState private var focusedField: CredentialsField?

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Printer Model")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Picker("Printer Model", selection: $vm.selectedPrinter) {
                        Text("Select a printer…")
                            .tag(BambuPrinter?.none)
                        ForEach(PrinterFamily.allCases) { family in
                            Section(family.displayName) {
                                ForEach(family.models) { printer in
                                    Text(printer.displayName)
                                        .tag(BambuPrinter?.some(printer))
                                }
                            }
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))

                CredentialsForm(focusedField: $focusedField)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                focusedField = nil
                Task { await viewModel.testAndSave() }
            } label: {
                Group {
                    if viewModel.isTesting {
                        ProgressView()
                    } else {
                        Text("Connect")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.selectedPrinter == nil || !viewModel.canConnect || viewModel.isTesting)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
        }
        .navigationTitle("Connect")
    }
}

#Preview {
    DirectConnectView()
        .environment(OnboardingViewModel())
}

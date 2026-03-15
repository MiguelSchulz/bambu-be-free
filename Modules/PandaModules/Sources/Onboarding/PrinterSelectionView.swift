import NavigatorUI
import PandaModels
import SFSafeSymbols
import SwiftUI

struct PrinterSelectionView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.navigator) private var navigator

    var body: some View {
        SetupStepLayout(step: .printerSelection, isNextDisabled: viewModel.selectedPrinter == nil) {
            if let next = viewModel.destination(after: .printerSelection) {
                navigator.navigate(to: next)
            }
        } content: {
            VStack(spacing: 0) {
                ForEach(PrinterFamily.allCases) { family in
                    Section {
                        ForEach(family.models) { printer in
                            printerRow(printer)
                        }
                    } header: {
                        Text(family.displayName)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        }
        .navigationTitle("Printer Model")
    }

    private func printerRow(_ printer: BambuPrinter) -> some View {
        Button {
            viewModel.selectedPrinter = printer
        } label: {
            HStack {
                Text(printer.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if viewModel.selectedPrinter == printer {
                    Image(systemSymbol: .checkmarkCircleFill)
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .accessibilityAddTraits(viewModel.selectedPrinter == printer ? .isSelected : [])
    }
}

#Preview {
    PrinterSelectionView()
        .environment(OnboardingViewModel())
}

import PandaModels
import SFSafeSymbols
import SwiftUI
import UniformTypeIdentifiers

private struct LogDocument: Transferable {
    let text: String
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { doc in
            Data(doc.text.utf8)
        }
        .suggestedFileName { $0.fileName }
    }
}

private enum GenerationState {
    case idle(entryCount: Int)
    case generating
    case ready(preview: String, export: String)
}

public struct SessionLogView: View {
    @State private var state = GenerationState.idle(entryCount: 0)
    @State private var liveEntryCount = 0
    @State private var countTimer: Timer?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                infoSection

                switch state {
                case .idle:
                    EmptyView()
                case .generating:
                    EmptyView()
                case let .ready(preview, _):
                    logPreviewSection(preview)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Session Log")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomButton
        }
        .onAppear { startLiveCount() }
        .onDisappear {
            countTimer?.invalidate()
            // Safety net: ensure logging resumes if user leaves during generation
            SessionLogger.shared.resume()
        }
    }

    private func startLiveCount() {
        liveEntryCount = SessionLogger.shared.entryCount()
        countTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            liveEntryCount = SessionLogger.shared.entryCount()
        }
    }

    private func generate() {
        state = .generating
        SessionLogger.shared.pause()
        countTimer?.invalidate()
        Task {
            let full = await SessionLogger.shared.formattedLog()
            let preview = await SessionLogger.shared.formattedPreview()
            state = .ready(preview: preview, export: full)
            SessionLogger.shared.resume()
        }
    }

    private static func logFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "y-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "PandaBeFree-Log_\(formatter.string(from: .now)).txt"
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What is this?", systemSymbol: .infoCircleFill)
                .font(.headline)

            Text("This log captures connection events, printer status changes, and errors during your current session. It helps diagnose issues with printer connectivity and app behavior.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label("Privacy", systemSymbol: .lockFill)
                .font(.headline)
                .padding(.top, 4)

            Text("No personal information, passwords, or access codes are included in the log. Logs are stored only in memory and are cleared when the app is restarted. Nothing is shared automatically \u{2014} you choose when and how to export.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label("Sharing Tips", systemSymbol: .lightbulbFill)
                .font(.headline)
                .padding(.top, 4)

            Text("When sharing a log, please also describe:\n\u{2022} What you were trying to do\n\u{2022} How the app behaved in the UI\n\u{2022} What you expected to happen or suggest to improve")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if case .idle = state {
                HStack {
                    Image(systemSymbol: .circleFill)
                        .font(.system(size: 8))
                        .foregroundStyle(.green)
                    Text("Recording \u{2014} \(liveEntryCount) entries captured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
    }

    // MARK: - Log Preview

    private func logPreviewSection(_ preview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Log Preview", systemSymbol: .docTextMagnifyingglass)
                .font(.headline)

            Text(preview)
                .font(.caption.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        Group {
            switch state {
            case .idle:
                Button(action: generate) {
                    Label("Generate Session Log", systemSymbol: .docTextMagnifyingglass)
                        .frame(maxWidth: .infinity)
                }
                .disabled(liveEntryCount == 0)

            case .generating:
                Button {} label: {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Generating log\u{2026}")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(true)

            case let .ready(_, export):
                ShareLink(
                    item: LogDocument(text: export, fileName: Self.logFileName()),
                    preview: SharePreview("PandaBeFree Session Log", image: Image(systemSymbol: .docText))
                ) {
                    Label("Export Session Log", systemSymbol: .squareAndArrowUp)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        SessionLogView()
    }
}

import NavigatorUI
import PandaModels
import PandaUI
import Shimmer
import SwiftUI
import WidgetKit

struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var viewModel: DashboardViewModel
    @State private var isFullscreen = false
    @State private var showConnectionError = false
    @State private var connectionErrorMessage = ""

    private var isLoading: Bool {
        !viewModel.hasReceivedInitialData
    }

    var body: some View {
        ManagedNavigationStack {
            dashboardContent
                .navigationTitle("Dashboard")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Disconnect") {
                            viewModel.showDisconnectConfirmation = true
                        }
                        .confirmationDialog(
                            "Disconnect from Printer?",
                            isPresented: $viewModel.showDisconnectConfirmation
                        ) {
                            Button("Disconnect", role: .destructive) {
                                viewModel.clearConfigAndDisconnect()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("This will disconnect from the printer and return to the setup screen.")
                        }
                    }
                }
        }
        .task {
            await viewModel.connectAll()
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhase(newPhase)
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            FullscreenCameraView(
                cameraProvider: viewModel.cameraManager,
                isPresented: $isFullscreen,
                isLightOn: viewModel.chamberLightOn,
                onToggleLight: viewModel.isConnected ? { viewModel.toggleLight(on: $0) } : nil
            )
        }
        .onChange(of: viewModel.mqttConnectionState) { _, newState in
            if case let .error(message) = newState {
                connectionErrorMessage = message
                showConnectionError = true
            }
        }
        .alert("Connection Failed", isPresented: $showConnectionError) {
            Button("Retry", role: .cancel) {
                viewModel.disconnectAll()
                Task { await viewModel.connectAll() }
            }
            Button("Disconnect", role: .destructive) {
                viewModel.clearConfigAndDisconnect()
            }
        } message: {
            Text(connectionErrorMessage)
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                CameraCard(
                    cameraProvider: viewModel.cameraManager,
                    isLightOn: viewModel.chamberLightOn,
                    onToggleLight: viewModel.isConnected ? { viewModel.toggleLight(on: $0) } : nil,
                    onTapFullscreen: { isFullscreen = true }
                )
                .redacted(reason: isLoading ? .placeholder : [])
                .shimmering(active: isLoading)

                PrintProgressSection(state: viewModel.contentState)
                    .redacted(reason: isLoading ? .placeholder : [])
                    .shimmering(active: isLoading)

                TemperatureSection(viewModel: viewModel)
                    .redacted(reason: isLoading ? .placeholder : [])
                    .shimmering(active: isLoading)

                FanSection(viewModel: viewModel)
                    .redacted(reason: isLoading ? .placeholder : [])
                    .shimmering(active: isLoading)

                if viewModel.isConnected && !viewModel.printerState.amsUnits.isEmpty {
                    ForEach(viewModel.printerState.amsUnits) { amsUnit in
                        AMSSection(viewModel: viewModel, amsUnit: amsUnit)
                    }
                }

                if viewModel.isPrinting || viewModel.canResume {
                    PrinterControlsSection(viewModel: viewModel)
                }

                if viewModel.isPrinting {
                    SpeedControlSection(viewModel: viewModel)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            viewModel.disconnectAll()
            async let connect: Void = viewModel.connectAll()
            async let minDelay: Void = { try? await Task.sleep(for: .seconds(1)) }()
            _ = await (connect, minDelay)
        }
        .sheet(isPresented: $viewModel.showDryingSheet) {
            DryingSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showFilamentEditSheet) {
            FilamentEditSheet(viewModel: viewModel)
        }
        .alert("Stop Drying", isPresented: $viewModel.showStopDryingConfirmation) {
            Button("Stop", role: .destructive) { viewModel.stopDrying() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to stop the drying cycle?")
        }
    }
}

#Preview {
    DashboardView(viewModel: .preview)
}

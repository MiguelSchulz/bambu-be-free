import PandaModels
import PandaNotifications
import SFSafeSymbols
import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var authStatus: NotificationAuthStatus = .notDetermined
    @State private var enabledStates: [NotificationType: Bool] = [:]
    @State private var showDeniedAlert = false

    private let scheduler = LocalNotificationScheduler.shared

    var body: some View {
        List {
            permissionSection
            notificationTypesSection
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refreshStatus() }
            }
        }
        .alert("Notifications Disabled", isPresented: $showDeniedAlert) {
            Button("Open Settings") {
                openNotificationSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To receive notifications, enable them in Settings.")
        }
    }

    // MARK: - Permission Section

    private var permissionSection: some View {
        Section {
            switch authStatus {
            case .authorized, .provisional:
                Label("Notifications Enabled", systemSymbol: .bellBadgeFill)
                    .foregroundStyle(.green)
            case .notDetermined:
                Button {
                    Task {
                        _ = await scheduler.requestAuthorization()
                        await refreshStatus()
                    }
                } label: {
                    Label("Enable Notifications", systemSymbol: .bellFill)
                }
            case .denied:
                HStack {
                    Label("Notifications Disabled", systemSymbol: .bellSlashFill)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Settings") {
                        openNotificationSettings()
                    }
                    .font(.subheadline)
                }
            }
        } header: {
            Text("Permission")
        }
    }

    // MARK: - Notification Types Section

    private var notificationTypesSection: some View {
        Section {
            ForEach(NotificationType.allCases, id: \.self) { type in
                Toggle(isOn: binding(for: type)) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                            Text(type.displayDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemSymbol: type.symbol)
                    }
                }
                .disabled(authStatus != .authorized && authStatus != .provisional)
                .onTapGesture {
                    if authStatus == .denied {
                        showDeniedAlert = true
                    }
                }
            }
        } header: {
            Text("Notification Types")
        }
    }

    // MARK: - Helpers

    private func binding(for type: NotificationType) -> Binding<Bool> {
        Binding(
            get: { enabledStates[type] ?? true },
            set: { newValue in
                enabledStates[type] = newValue
                NotificationSettings.setEnabled(type, enabled: newValue)
                // Immediately re-evaluate notifications
                if let cached = SharedSettings.cachedPrinterState {
                    let actions = NotificationEvaluator.evaluate(
                        contentState: cached.contentState,
                        amsUnits: cached.amsUnits
                    )
                    Task { await scheduler.execute(actions) }
                }
            }
        )
    }

    private func refreshStatus() async {
        authStatus = await scheduler.authorizationStatus()
        for type in NotificationType.allCases {
            enabledStates[type] = NotificationSettings.isEnabled(type)
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}

import NavigatorUI
import PandaUI
import SwiftUI
import UserNotifications

struct NotificationStepView: View {
    @Environment(\.navigator) private var navigator
    @State private var authStatus: UNAuthorizationStatus?

    var body: some View {
        SetupStepLayout(step: .notifications) {
            Task {
                if authStatus == .notDetermined {
                    _ = try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound, .badge])
                }
                navigator.navigate(to: OnboardingDestinations.guidedSlicerSetup)
            }
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(
                    icon: .bellBadgeFill,
                    text: "Receive a notification when your **print finishes**."
                )
                InstructionRow(
                    icon: .humidityFill,
                    text: "Receive a notification when **filament drying** completes."
                )
                InstructionRow(
                    icon: .gearshapeFill,
                    text: "You can change notification preferences anytime in **More > Notifications**."
                )
            }
        }
        .navigationTitle("Notifications")
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            authStatus = settings.authorizationStatus
            // Auto-skip if already authorized or previously denied
            if settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .denied
            {
                navigator.navigate(to: OnboardingDestinations.guidedSlicerSetup)
            }
        }
    }
}

#Preview {
    NotificationStepView()
}

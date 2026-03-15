import NavigatorUI
import PandaUI
import SwiftUI
import UserNotifications

struct NotificationStepView: View {
    @Environment(OnboardingViewModel.self) private var viewModel
    @Environment(\.navigator) private var navigator

    var body: some View {
        SetupStepLayout(step: .notifications) {
            Task {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
                if let next = viewModel.destination(after: .notifications) {
                    navigator.navigate(to: next)
                }
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
    }
}

#Preview {
    NotificationStepView()
        .environment(OnboardingViewModel())
}

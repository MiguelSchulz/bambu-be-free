import UserNotifications

/// Real implementation using UNUserNotificationCenter.
/// Safe to use from both app and extension contexts.
public final class LocalNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    public static let shared = LocalNotificationScheduler()

    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func schedule(
        identifier: String,
        title: String,
        body: String,
        fireDate: Date
    ) async {
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, interval),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    public func cancel(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    public func cancelAll(withPrefix prefix: String) async {
        let pending = await center.pendingNotificationRequests()
        let matching = pending
            .filter { $0.identifier.hasPrefix(prefix) }
            .map(\.identifier)
        if !matching.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: matching)
        }
    }

    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func authorizationStatus() async -> NotificationAuthStatus {
        let settings = await center.notificationSettings()
        return switch settings.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        case .provisional: .provisional
        case .ephemeral: .authorized
        @unknown default: .denied
        }
    }
}

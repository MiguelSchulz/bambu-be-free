import Foundation
@testable import PandaNotifications

final class MockNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    struct ScheduledNotification: Equatable {
        let identifier: String
        let title: String
        let body: String
        let fireDate: Date
    }

    private(set) var scheduledNotifications: [ScheduledNotification] = []
    private(set) var cancelledIdentifiers: [String] = []
    private(set) var cancelledPrefixes: [String] = []
    var authorizationGranted = true
    var currentAuthStatus: NotificationAuthStatus = .authorized

    func schedule(identifier: String, title: String, body: String, fireDate: Date) async {
        scheduledNotifications.append(ScheduledNotification(
            identifier: identifier, title: title, body: body, fireDate: fireDate
        ))
    }

    func cancel(identifier: String) async {
        cancelledIdentifiers.append(identifier)
    }

    func cancelAll(withPrefix prefix: String) async {
        cancelledPrefixes.append(prefix)
    }

    func requestAuthorization() async -> Bool {
        authorizationGranted
    }

    func authorizationStatus() async -> NotificationAuthStatus {
        currentAuthStatus
    }

    func reset() {
        scheduledNotifications.removeAll()
        cancelledIdentifiers.removeAll()
        cancelledPrefixes.removeAll()
    }
}

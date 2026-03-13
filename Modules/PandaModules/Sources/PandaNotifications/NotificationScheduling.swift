import Foundation

/// Authorization status for notifications.
public enum NotificationAuthStatus: Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
}

/// Protocol for scheduling/cancelling local notifications.
/// Abstracts UNUserNotificationCenter for testability.
public protocol NotificationScheduling: Sendable {
    /// Schedule a notification to fire at a specific date.
    /// If a notification with the same identifier already exists, it is replaced.
    func schedule(
        identifier: String,
        title: String,
        body: String,
        fireDate: Date
    ) async

    /// Cancel a pending notification by identifier.
    func cancel(identifier: String) async

    /// Cancel all pending notifications matching a prefix.
    func cancelAll(withPrefix prefix: String) async

    /// Request notification authorization. Returns whether granted.
    func requestAuthorization() async -> Bool

    /// Check current authorization status.
    func authorizationStatus() async -> NotificationAuthStatus
}

public extension NotificationScheduling {
    /// Execute a batch of evaluator actions.
    func execute(_ actions: [NotificationEvaluator.Action]) async {
        for action in actions {
            switch action {
            case let .schedule(id, title, body, fireDate):
                await schedule(identifier: id, title: title, body: body, fireDate: fireDate)
            case let .cancel(id):
                await cancel(identifier: id)
            }
        }
    }
}

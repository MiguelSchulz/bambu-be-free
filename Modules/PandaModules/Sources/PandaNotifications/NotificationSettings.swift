import Foundation
import PandaModels

/// Manages per-type notification preferences in shared UserDefaults.
/// Accessible from both main app and widget extension.
public enum NotificationSettings {
    /// Check if a notification type is enabled. Defaults to true.
    public static func isEnabled(_ type: NotificationType) -> Bool {
        SharedSettings.sharedDefaults?.object(forKey: type.settingsKey) as? Bool ?? true
    }

    /// Set the enabled state for a notification type.
    public static func setEnabled(_ type: NotificationType, enabled: Bool) {
        SharedSettings.sharedDefaults?.set(enabled, forKey: type.settingsKey)
    }
}

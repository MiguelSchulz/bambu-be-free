import Foundation
import PandaModels
@testable import PandaNotifications
import Testing

struct NotificationSettingsTests {
    @Test("Defaults to enabled for all types", arguments: NotificationType.allCases)
    func defaultsToEnabled(type: NotificationType) {
        // Remove any existing value to test the default
        SharedSettings.sharedDefaults?.removeObject(forKey: type.settingsKey)
        #expect(NotificationSettings.isEnabled(type) == true)
    }

    @Test("Persists disabled state")
    func persistsDisabled() {
        let type = NotificationType.printFinished
        NotificationSettings.setEnabled(type, enabled: false)
        defer { SharedSettings.sharedDefaults?.removeObject(forKey: type.settingsKey) }

        #expect(NotificationSettings.isEnabled(type) == false)
    }

    @Test("Persists enabled state after being disabled")
    func persistsEnabled() {
        let type = NotificationType.dryingFinished
        NotificationSettings.setEnabled(type, enabled: false)
        NotificationSettings.setEnabled(type, enabled: true)
        defer { SharedSettings.sharedDefaults?.removeObject(forKey: type.settingsKey) }

        #expect(NotificationSettings.isEnabled(type) == true)
    }
}

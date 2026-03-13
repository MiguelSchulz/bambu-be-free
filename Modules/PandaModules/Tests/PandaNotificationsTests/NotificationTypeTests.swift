import Foundation
@testable import PandaNotifications
import Testing

struct NotificationTypeTests {
    @Test("All types have non-empty display name", arguments: NotificationType.allCases)
    func displayNameNotEmpty(type: NotificationType) {
        #expect(String(localized: type.displayName).isEmpty == false)
    }

    @Test("All types have non-empty description", arguments: NotificationType.allCases)
    func descriptionNotEmpty(type: NotificationType) {
        #expect(String(localized: type.displayDescription).isEmpty == false)
    }

    @Test("Print finished identifier is stable")
    func printIdentifier() {
        #expect(NotificationType.printFinished.identifier() == "panda.print.finished")
    }

    @Test("Print finished identifier ignores amsId")
    func printIdentifierIgnoresAmsId() {
        #expect(NotificationType.printFinished.identifier(amsId: 5) == "panda.print.finished")
    }

    @Test("Drying identifier includes AMS ID")
    func dryingIdentifierWithAmsId() {
        #expect(NotificationType.dryingFinished.identifier(amsId: 0) == "panda.drying.finished.ams0")
        #expect(NotificationType.dryingFinished.identifier(amsId: 3) == "panda.drying.finished.ams3")
    }

    @Test("Drying identifier without AMS ID returns base")
    func dryingIdentifierWithoutAmsId() {
        #expect(NotificationType.dryingFinished.identifier() == "panda.drying.finished")
    }

    @Test("Settings keys are unique across all types")
    func uniqueSettingsKeys() {
        let keys = NotificationType.allCases.map(\.settingsKey)
        #expect(Set(keys).count == keys.count, "Settings keys must be unique")
    }

    @Test("Identifiers are unique across all types")
    func uniqueIdentifiers() {
        let ids = NotificationType.allCases.map { $0.identifier() }
        #expect(Set(ids).count == ids.count, "Base identifiers must be unique")
    }
}

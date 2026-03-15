import Foundation
import PandaLogger
import PandaModels
import UserNotifications

private let logCategory = "Onboarding"

@MainActor
@Observable
public final class OnboardingViewModel {
    public var ip = ""
    public var accessCode = ""
    public var serial = ""
    public var selectedPrinter: BambuPrinter?
    public var isTesting = false
    public var connectionError: String?
    public var needsNotificationStep = true

    public let connectionTester: @MainActor (String, String, String, BambuPrinter?) async -> String?

    public init(
        connectionTester: @escaping @MainActor (String, String, String, BambuPrinter?) async -> String? = { _, _, _, _ in nil }
    ) {
        self.connectionTester = connectionTester
    }

    public var serialRequired: Bool {
        selectedPrinter?.serialRequired ?? false
    }

    public var currentSteps: [OnboardingStep] {
        OnboardingStep.steps(for: selectedPrinter).filter { step in
            step != .notifications || needsNotificationStep
        }
    }

    public var canConnect: Bool {
        let hasIP = !ip.trimmingCharacters(in: .whitespaces).isEmpty
        let hasCode = !accessCode.trimmingCharacters(in: .whitespaces).isEmpty
        let hasSerial = !serial.trimmingCharacters(in: .whitespaces).isEmpty
        let serialOK = !serialRequired || hasSerial
        return hasIP && hasCode && serialOK
    }

    /// Returns the guided onboarding destination for the step after the given one,
    /// or `nil` if the given step is the last one.
    public func destination(after step: OnboardingStep) -> OnboardingDestinations? {
        let steps = currentSteps
        guard let index = steps.firstIndex(of: step),
              steps.index(after: index) < steps.endIndex
        else { return nil }
        return steps[steps.index(after: index)].destination
    }

    /// Check notification authorization and exclude the step if already determined.
    public func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        needsNotificationStep = settings.authorizationStatus == .notDetermined
    }

    public func testAndSave() async -> Bool {
        let success = await testConnection()
        if success { saveCredentials() }
        return success
    }

    public func testConnection() async -> Bool {
        let trimmedIP = ip.trimmingCharacters(in: .whitespaces)
        let trimmedCode = accessCode.trimmingCharacters(in: .whitespaces)
        let trimmedSerial = serial.trimmingCharacters(in: .whitespaces)

        appLog(.info, category: logCategory, "Testing connection — model: \(selectedPrinter?.displayName ?? "unknown"), IP: \(trimmedIP)")
        connectionError = nil
        isTesting = true
        defer { isTesting = false }

        if let error = await connectionTester(trimmedIP, trimmedCode, trimmedSerial, selectedPrinter) {
            appLog(.error, category: logCategory, "Connection test failed: \(error)")
            connectionError = error
            return false
        }
        appLog(.info, category: logCategory, "Connection test passed")
        return true
    }

    public func saveCredentials() {
        appLog(.info, category: logCategory, "Saving credentials — model: \(selectedPrinter?.displayName ?? "unknown")")
        SharedSettings.printerIP = ip.trimmingCharacters(in: .whitespaces)
        SharedSettings.printerAccessCode = accessCode.trimmingCharacters(in: .whitespaces)
        SharedSettings.printerSerial = serial.trimmingCharacters(in: .whitespaces)
        SharedSettings.printerModel = selectedPrinter
    }
}

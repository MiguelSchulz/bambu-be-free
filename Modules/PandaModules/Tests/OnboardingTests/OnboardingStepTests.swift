@testable import Onboarding
import Testing

@Suite("Onboarding Steps")
struct OnboardingStepTests {
    @Test("Total steps count")
    func totalSteps() {
        #expect(OnboardingStep.totalSteps == 6)
    }

    @Test("Step numbers are 1-based",
          arguments: [
              (OnboardingStep.lanMode, 1),
              (OnboardingStep.devMode, 2),
              (OnboardingStep.credentials, 3),
              (OnboardingStep.enterCredentials, 4),
              (OnboardingStep.notifications, 5),
              (OnboardingStep.slicerSetup, 6),
          ])
    func stepNumbers(step: OnboardingStep, expected: Int) {
        #expect(step.stepNumber == expected)
    }

    @Test("Steps are in correct order")
    func stepOrder() {
        let steps = OnboardingStep.allCases
        #expect(steps[0] == .lanMode)
        #expect(steps[1] == .devMode)
        #expect(steps[2] == .credentials)
        #expect(steps[3] == .enterCredentials)
        #expect(steps[4] == .notifications)
        #expect(steps[5] == .slicerSetup)
    }

    @Test("All steps have non-empty titles", arguments: OnboardingStep.allCases)
    func titlesNotEmpty(step: OnboardingStep) {
        #expect(step.title.key.isEmpty == false)
    }

    @Test("All steps have non-empty descriptions", arguments: OnboardingStep.allCases)
    func descriptionsNotEmpty(step: OnboardingStep) {
        #expect(step.description.key.isEmpty == false)
    }

    @Test("All steps have non-empty system symbols", arguments: OnboardingStep.allCases)
    func systemSymbolsNotEmpty(step: OnboardingStep) {
        #expect(step.systemSymbol.rawValue.isEmpty == false)
    }

    @Test("Wiki URLs are set for informational steps",
          arguments: [
              OnboardingStep.lanMode,
              OnboardingStep.devMode,
              OnboardingStep.credentials,
              OnboardingStep.slicerSetup,
          ])
    func wikiURLsExist(step: OnboardingStep) {
        #expect(step.wikiURL != nil)
    }

    @Test("Steps without wiki URLs",
          arguments: [OnboardingStep.enterCredentials, OnboardingStep.notifications])
    func noWikiURL(step: OnboardingStep) {
        #expect(step.wikiURL == nil)
    }
}

@testable import Onboarding
@testable import PandaModels
import Testing

@Suite("Onboarding ViewModel")
@MainActor
struct OnboardingViewModelTests {
    // MARK: - Default State

    @Test("Default values are empty")
    func defaultValues() {
        let vm = OnboardingViewModel()
        #expect(vm.ip == "")
        #expect(vm.accessCode == "")
        #expect(vm.serial == "")
        #expect(vm.selectedPrinter == nil)
        #expect(vm.isTesting == false)
        #expect(vm.connectionError == nil)
    }

    // MARK: - selectedPrinter

    @Test("serialRequired derives from selected printer")
    func serialRequiredFromPrinter() {
        let vm = OnboardingViewModel()
        #expect(vm.serialRequired == false)

        vm.selectedPrinter = .a1
        #expect(vm.serialRequired == true)

        vm.selectedPrinter = .a1Mini
        #expect(vm.serialRequired == true)

        vm.selectedPrinter = .x1c
        #expect(vm.serialRequired == false)
    }

    @Test("currentSteps includes notifications when needed")
    func currentStepsWithNotifications() {
        let vm = OnboardingViewModel()
        vm.needsNotificationStep = true
        #expect(vm.currentSteps.contains(.notifications))
    }

    @Test("currentSteps excludes notifications when not needed")
    func currentStepsWithoutNotifications() {
        let vm = OnboardingViewModel()
        vm.needsNotificationStep = false
        #expect(!vm.currentSteps.contains(.notifications))
    }

    @Test("destination(after:) returns correct next step")
    func destinationAfterStep() {
        let vm = OnboardingViewModel()
        vm.needsNotificationStep = true
        #expect(vm.destination(after: .printerSelection) == .guidedPrinterSetup)
        #expect(vm.destination(after: .enterCredentials) == .guidedNotifications)
        #expect(vm.destination(after: .slicerSetup) == nil)
    }

    @Test("destination(after:) skips notifications when excluded")
    func destinationSkipsNotifications() {
        let vm = OnboardingViewModel()
        vm.needsNotificationStep = false
        #expect(vm.destination(after: .enterCredentials) == .guidedSlicerSetup)
    }

    // MARK: - canConnect

    @Test("canConnect is false when both fields empty")
    func canConnectBothEmpty() {
        let vm = OnboardingViewModel()
        #expect(vm.canConnect == false)
    }

    @Test("canConnect is false when IP empty")
    func canConnectIPEmpty() {
        let vm = OnboardingViewModel()
        vm.accessCode = "12345678"
        #expect(vm.canConnect == false)
    }

    @Test("canConnect is false when access code empty")
    func canConnectAccessCodeEmpty() {
        let vm = OnboardingViewModel()
        vm.ip = "192.168.1.100"
        #expect(vm.canConnect == false)
    }

    @Test("canConnect is true when both non-empty")
    func canConnectBothFilled() {
        let vm = OnboardingViewModel()
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"
        #expect(vm.canConnect)
    }

    @Test("canConnect is false when IP is only whitespace")
    func canConnectWhitespaceIP() {
        let vm = OnboardingViewModel()
        vm.ip = "   "
        vm.accessCode = "12345678"
        #expect(vm.canConnect == false)
    }

    @Test("canConnect is false when access code is only whitespace")
    func canConnectWhitespaceAccessCode() {
        let vm = OnboardingViewModel()
        vm.ip = "192.168.1.100"
        vm.accessCode = "   "
        #expect(vm.canConnect == false)
    }

    @Test("canConnect requires serial when printer model requires it")
    func canConnectSerialRequired() {
        let vm = OnboardingViewModel()
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"
        vm.selectedPrinter = .a1
        #expect(vm.canConnect == false) // serial missing

        vm.serial = "01S00A000000"
        #expect(vm.canConnect == true)
    }

    @Test("canConnect does not require serial for non-serial printers")
    func canConnectSerialNotRequired() {
        let vm = OnboardingViewModel()
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"
        vm.selectedPrinter = .x1c
        #expect(vm.canConnect == true) // no serial needed
    }

    // MARK: - testConnection

    @Test("testConnection succeeds without saving credentials")
    func connectionSuccess() async {
        SharedSettings.printerIP = ""
        let vm = OnboardingViewModel { _, _, _, _ in nil }
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"

        let result = await vm.testConnection()
        #expect(result)
        #expect(vm.connectionError == nil)
        #expect(vm.isTesting == false)
        #expect(SharedSettings.printerIP == "")
    }

    @Test("testConnection fails and sets error")
    func connectionFailure() async {
        let vm = OnboardingViewModel { _, _, _, _ in "Connection refused" }
        vm.ip = "192.168.1.100"
        vm.accessCode = "wrong"

        let result = await vm.testConnection()
        #expect(result == false)
        #expect(vm.connectionError == "Connection refused")
        #expect(vm.isTesting == false)
    }

    @Test("testConnection trims whitespace before testing")
    func connectionTrimsWhitespace() async {
        var testedIP = ""
        var testedCode = ""
        let vm = OnboardingViewModel { ip, code, _, _ in
            testedIP = ip
            testedCode = code
            return nil
        }
        vm.ip = "  192.168.1.100  "
        vm.accessCode = "  12345678  "

        _ = await vm.testConnection()
        #expect(testedIP == "192.168.1.100")
        #expect(testedCode == "12345678")
    }

    @Test("testConnection passes printer model to tester")
    func connectionPassesPrinterModel() async {
        var testedModel: BambuPrinter?
        let vm = OnboardingViewModel { _, _, _, model in
            testedModel = model
            return nil
        }
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"
        vm.selectedPrinter = .p2s

        _ = await vm.testConnection()
        #expect(testedModel == .p2s)
    }

    // MARK: - testAndSave

    @Test("testAndSave succeeds and saves credentials")
    func andSaveSuccess() async {
        let vm = OnboardingViewModel { _, _, _, _ in nil }
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"
        vm.selectedPrinter = .x1c

        let result = await vm.testAndSave()
        #expect(result)
        #expect(vm.connectionError == nil)
        #expect(vm.isTesting == false)
        #expect(SharedSettings.printerIP == "192.168.1.100")
        #expect(SharedSettings.printerModel == .x1c)
    }

    @Test("testAndSave fails and does not save")
    func andSaveFailure() async {
        SharedSettings.printerIP = ""
        SharedSettings.printerModel = nil
        let vm = OnboardingViewModel { _, _, _, _ in "Connection refused" }
        vm.ip = "192.168.1.100"
        vm.accessCode = "wrong"
        vm.selectedPrinter = .a1

        let result = await vm.testAndSave()
        #expect(result == false)
        #expect(vm.connectionError == "Connection refused")
        #expect(SharedSettings.printerIP == "")
        #expect(SharedSettings.printerModel == nil)
    }

    // MARK: - saveCredentials

    @Test("saveCredentials trims whitespace")
    func saveCredentialsTrimming() {
        let vm = OnboardingViewModel()
        vm.ip = "  192.168.1.100  "
        vm.accessCode = "  12345678  "
        vm.saveCredentials()

        #expect(SharedSettings.printerIP == "192.168.1.100")
        #expect(SharedSettings.printerAccessCode == "12345678")
    }

    @Test("saveCredentials saves printer model")
    func saveCredentialsPrinterModel() {
        let vm = OnboardingViewModel()
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"
        vm.selectedPrinter = .p2s
        vm.saveCredentials()

        #expect(SharedSettings.printerModel == .p2s)
        #expect(SharedSettings.printerType == .rtsp) // derived from model
    }

    @Test("saveCredentials with no printer model saves nil")
    func saveCredentialsNoPrinterModel() {
        SharedSettings.printerModel = .x1c
        let vm = OnboardingViewModel()
        vm.ip = "192.168.1.100"
        vm.accessCode = "12345678"
        vm.saveCredentials()

        #expect(SharedSettings.printerModel == nil)
    }
}

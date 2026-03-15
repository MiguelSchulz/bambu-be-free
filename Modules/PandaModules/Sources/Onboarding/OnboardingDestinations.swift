import NavigatorUI
import SwiftUI

public nonisolated enum OnboardingDestinations: NavigationDestination {
    case directConnect
    case guidedPrinterSelection
    case guidedPrinterSetup
    case guidedCredentials
    case guidedEnterCredentials
    case guidedNotifications
    case guidedSlicerSetup

    public var body: some View {
        switch self {
        case .directConnect:
            DirectConnectView()
        case .guidedPrinterSelection:
            PrinterSelectionView()
        case .guidedPrinterSetup:
            PrinterSetupStepView()
        case .guidedCredentials:
            CredentialsStepView()
        case .guidedEnterCredentials:
            EnterCredentialsView()
        case .guidedNotifications:
            NotificationStepView()
        case .guidedSlicerSetup:
            SlicerSetupView()
        }
    }
}

import NavigatorUI
import Networking
import Onboarding
import PandaModels
import PrinterControl
import SFSafeSymbols
import SwiftUI

enum RootTab: Hashable {
    case dashboard
    case control
    case more
}

@main
struct PandaBeFreeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    /// @AppStorage is needed here for SwiftUI reactivity — when clearConfigAndDisconnect()
    /// clears these values, SwiftUI re-evaluates body and switches to onboarding.
    @AppStorage("printerIP", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var printerIP = ""
    @AppStorage("printerAccessCode", store: UserDefaults(suiteName: SharedSettings.suiteName))
    private var accessCode = ""
    @State private var selectedTab: RootTab = .dashboard
    @State private var dashboardViewModel = DashboardViewModel()

    private var hasConfig: Bool {
        !printerIP.isEmpty && !accessCode.isEmpty
    }

    init() {
        SharedSettings.migrateFromStandardDefaults()
    }

    var body: some Scene {
        WindowGroup {
            if hasConfig {
                TabView(selection: $selectedTab) {
                    Tab("Dashboard", systemImage: SFSymbol.printerFill.rawValue, value: RootTab.dashboard) {
                        DashboardView(viewModel: dashboardViewModel)
                    }
                    Tab("Control", systemImage: SFSymbol.gamecontrollerFill.rawValue, value: RootTab.control) {
                        PrinterControlView(
                            mqttService: dashboardViewModel.mqttServiceRef,
                            cameraProvider: dashboardViewModel.cameraManager,
                            isLightOn: dashboardViewModel.chamberLightOn,
                            printerState: dashboardViewModel.printerState
                        )
                    }
                    Tab("More", systemImage: SFSymbol.ellipsisCircle.rawValue, value: RootTab.more) {
                        MoreView()
                    }
                }
                .onNavigationReceive(assign: $selectedTab)
            } else {
                OnboardingRootView { ip, accessCode, serial, printerModel in
                    await ConnectionTestService.testConnection(
                        ip: ip,
                        accessCode: accessCode,
                        serial: serial,
                        printerModel: printerModel
                    )
                }
            }
        }
    }
}

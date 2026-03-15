import Foundation
import PandaModels
import SFSafeSymbols

public enum OnboardingStep: Int, CaseIterable, Sendable {
    case printerSelection
    case printerSetup
    case credentials
    case enterCredentials
    case notifications
    case slicerSetup

    /// Dynamic step list for the guided onboarding flow.
    /// All printers currently share the same steps; this infrastructure
    /// supports per-model variation in the future.
    public static func steps(for _: BambuPrinter?) -> [OnboardingStep] {
        allCases
    }

    public var stepNumber: Int {
        rawValue + 1
    }

    public static var totalSteps: Int {
        allCases.count
    }

    public var title: LocalizedStringResource {
        switch self {
        case .printerSelection: "Select Your Printer"
        case .printerSetup: "Enable LAN & Developer Mode"
        case .credentials: "Find Your Credentials"
        case .enterCredentials: "Enter Credentials"
        case .notifications: "Enable Notifications"
        case .slicerSetup: "Configure Your Slicer"
        }
    }

    public var description: LocalizedStringResource {
        switch self {
        case .printerSelection:
            "Choose your Bambu Lab printer model so we can configure the best settings for your setup."
        case .printerSetup:
            "LAN Mode and Developer Mode allow third-party apps like this one to communicate directly with your printer over your local network."
        case .credentials:
            "You'll need the following information from your printer:"
        case .enterCredentials:
            "Enter the IP address and access code you found on your printer."
        case .notifications:
            "Get notified when your prints and drying cycles finish — even when the app is in the background."
        case .slicerSetup:
            "To send prints over LAN, you'll also need to update your slicer's connection settings."
        }
    }

    public var systemSymbol: SFSymbol {
        switch self {
        case .printerSelection: .printerFill
        case .printerSetup: .wifiRouter
        case .credentials: .keyFill
        case .enterCredentials: .rectangleAndPencilAndEllipsis
        case .notifications: .bellBadgeFill
        case .slicerSetup: .desktopcomputer
        }
    }

    /// The navigation destination corresponding to this step's guided view.
    public var destination: OnboardingDestinations {
        switch self {
        case .printerSelection: .guidedPrinterSelection
        case .printerSetup: .guidedPrinterSetup
        case .credentials: .guidedCredentials
        case .enterCredentials: .guidedEnterCredentials
        case .notifications: .guidedNotifications
        case .slicerSetup: .guidedSlicerSetup
        }
    }

    public var wikiURL: URL? {
        switch self {
        case .printerSelection:
            nil
        case .printerSetup:
            nil
        case .credentials:
            URL(string: "https://wiki.bambulab.com/en/knowledge-sharing/access-code-connect")
        case .enterCredentials:
            nil
        case .notifications:
            nil
        case .slicerSetup:
            URL(string: "https://wiki.bambulab.com/en/knowledge-sharing/access-code-connect")
        }
    }
}

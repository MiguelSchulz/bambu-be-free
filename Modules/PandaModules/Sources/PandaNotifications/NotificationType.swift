import Foundation
import SFSafeSymbols

/// Types of local notifications the app can schedule.
/// Add new cases to extend with future notification types.
public enum NotificationType: String, CaseIterable, Sendable {
    case printFinished = "panda.print.finished"
    case dryingFinished = "panda.drying.finished"

    /// Stable notification identifier. For drying, includes AMS unit ID.
    public func identifier(amsId: Int? = nil) -> String {
        switch self {
        case .printFinished:
            return rawValue
        case .dryingFinished:
            guard let amsId else { return rawValue }
            return "\(rawValue).ams\(amsId)"
        }
    }

    /// User-facing title for the settings UI.
    public var displayName: LocalizedStringResource {
        switch self {
        case .printFinished: "Print Finished"
        case .dryingFinished: "Drying Finished"
        }
    }

    /// User-facing description for the settings UI.
    public var displayDescription: LocalizedStringResource {
        switch self {
        case .printFinished: "Get notified when your print job completes."
        case .dryingFinished: "Get notified when AMS filament drying finishes."
        }
    }

    /// SF Symbol for the settings UI.
    public var symbol: SFSymbol {
        switch self {
        case .printFinished: .printerFilledAndPaper
        case .dryingFinished: .humidityFill
        }
    }

    /// SharedSettings key for this notification type's enabled state.
    public var settingsKey: String {
        "notification.\(rawValue).enabled"
    }
}

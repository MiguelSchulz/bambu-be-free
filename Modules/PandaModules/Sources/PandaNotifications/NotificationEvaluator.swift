import Foundation
import PandaModels

/// Pure-logic evaluator that determines which notifications to schedule or cancel
/// based on the current printer state. Returns actions without side effects.
public enum NotificationEvaluator {
    /// Action the scheduler should take.
    public enum Action: Equatable, Sendable {
        case schedule(identifier: String, title: String, body: String, fireDate: Date)
        case cancel(identifier: String)
    }

    /// Evaluate the current printer state and return notification actions.
    public static func evaluate(
        contentState: PrinterAttributes.ContentState,
        amsUnits: [AMSUnitSnapshot],
        now: Date = .now
    ) -> [Action] {
        var actions: [Action] = []

        // --- Print finished notification ---
        if NotificationSettings.isEnabled(.printFinished) {
            actions.append(contentsOf: evaluatePrint(
                contentState: contentState,
                now: now
            ))
        } else {
            actions.append(.cancel(identifier: NotificationType.printFinished.identifier()))
        }

        // --- Drying finished notifications ---
        if NotificationSettings.isEnabled(.dryingFinished) {
            actions.append(contentsOf: evaluateDrying(
                amsUnits: amsUnits,
                now: now
            ))
        } else {
            for unit in amsUnits {
                actions.append(.cancel(
                    identifier: NotificationType.dryingFinished.identifier(amsId: unit.id)
                ))
            }
        }

        return actions
    }

    // MARK: - Print evaluation

    private static func evaluatePrint(
        contentState: PrinterAttributes.ContentState,
        now: Date
    ) -> [Action] {
        let identifier = NotificationType.printFinished.identifier()

        switch contentState.status {
        case .printing, .preparing:
            guard contentState.remainingMinutes > 0 else {
                return [.cancel(identifier: identifier)]
            }
            let fireDate = now.addingTimeInterval(
                TimeInterval(contentState.remainingMinutes) * 60
            )
            let jobName = contentState.jobName.isEmpty
                ? String(localized: "3D Print")
                : contentState.jobName
            return [.schedule(
                identifier: identifier,
                title: String(localized: "Print Complete"),
                body: String(localized: "\(jobName) has finished printing."),
                fireDate: fireDate
            )]

        case .completed, .cancelled, .idle, .paused, .issue:
            return [.cancel(identifier: identifier)]
        }
    }

    // MARK: - Drying evaluation

    private static func evaluateDrying(
        amsUnits: [AMSUnitSnapshot],
        now: Date
    ) -> [Action] {
        var actions: [Action] = []

        for unit in amsUnits {
            let identifier = NotificationType.dryingFinished.identifier(amsId: unit.id)

            if unit.dryTimeRemaining > 0 {
                let fireDate = now.addingTimeInterval(
                    TimeInterval(unit.dryTimeRemaining) * 60
                )
                let unitName = if let typeName = unit.amsTypeName {
                    "\(typeName) \(unit.id + 1)"
                } else {
                    "AMS \(unit.id + 1)"
                }
                actions.append(.schedule(
                    identifier: identifier,
                    title: String(localized: "Drying Complete"),
                    body: String(localized: "\(unitName) has finished drying."),
                    fireDate: fireDate
                ))
            } else {
                actions.append(.cancel(identifier: identifier))
            }
        }

        return actions
    }
}

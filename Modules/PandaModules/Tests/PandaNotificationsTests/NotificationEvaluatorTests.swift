import Foundation
import PandaModels
@testable import PandaNotifications
import Testing

struct NotificationEvaluatorTests {
    /// Fixed reference date for deterministic tests
    let now = Date(timeIntervalSince1970: 1_000_000)

    // MARK: - Helpers

    private func makeContentState(
        status: PrinterStatus = .printing,
        remainingMinutes: Int = 60,
        jobName: String = "Benchy"
    ) -> PrinterAttributes.ContentState {
        PrinterAttributes.ContentState(
            progress: 42,
            remainingMinutes: remainingMinutes,
            jobName: jobName,
            layerNum: 100,
            totalLayers: 300,
            status: status
        )
    }

    private func makeAMSUnit(
        id: Int = 0,
        dryTimeRemaining: Int = 0,
        amsTypeName: String? = "AMS"
    ) -> AMSUnitSnapshot {
        AMSUnitSnapshot(
            id: id,
            amsTypeName: amsTypeName,
            dryTimeRemaining: dryTimeRemaining
        )
    }

    // MARK: - Print Notification: Scheduling

    @Test("Schedules print notification when printing with remaining time")
    func schedulePrintWhenPrinting() {
        let state = makeContentState(status: .printing, remainingMinutes: 60, jobName: "Benchy")
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [], now: now)

        let expectedFire = now.addingTimeInterval(60 * 60)
        #expect(actions.contains(.schedule(
            identifier: "panda.print.finished",
            title: "Print Complete",
            body: "Benchy has finished printing.",
            fireDate: expectedFire
        )))
    }

    @Test("Schedules print notification when preparing with remaining time")
    func schedulePrintWhenPreparing() {
        let state = makeContentState(status: .preparing, remainingMinutes: 120)
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [], now: now)

        let scheduleActions = actions.filter {
            if case let .schedule(id, _, _, _) = $0, id == "panda.print.finished" { return true }
            return false
        }
        #expect(scheduleActions.count == 1)
    }

    @Test("Uses default title when job name is empty")
    func defaultJobName() {
        let state = makeContentState(jobName: "")
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [], now: now)

        let scheduleAction = actions.first {
            if case let .schedule(id, _, _, _) = $0, id == "panda.print.finished" { return true }
            return false
        }
        if case let .schedule(_, _, body, _) = scheduleAction {
            #expect(body.contains("3D Print"))
        } else {
            Issue.record("Expected a schedule action for print finished")
        }
    }

    @Test("Fire date equals now + remainingMinutes * 60")
    func fireDateAccuracy() {
        let state = makeContentState(remainingMinutes: 45)
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [], now: now)

        let expectedFire = now.addingTimeInterval(45 * 60)
        if case let .schedule(_, _, _, fireDate) = actions.first(where: {
            if case let .schedule(id, _, _, _) = $0, id == "panda.print.finished" { return true }
            return false
        }) {
            #expect(fireDate == expectedFire)
        } else {
            Issue.record("Expected a schedule action")
        }
    }

    // MARK: - Print Notification: Cancellation

    @Test(
        "Cancels print notification for non-active statuses",
        arguments: [PrinterStatus.completed, .cancelled, .idle, .paused, .issue]
    )
    func cancelPrintForNonActiveStatus(status: PrinterStatus) {
        let state = makeContentState(status: status)
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [], now: now)

        #expect(actions.contains(.cancel(identifier: "panda.print.finished")))
    }

    @Test("Cancels print notification when remainingMinutes is 0")
    func cancelPrintWhenNoTimeRemaining() {
        let state = makeContentState(status: .printing, remainingMinutes: 0)
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [], now: now)

        #expect(actions.contains(.cancel(identifier: "panda.print.finished")))
    }

    @Test("Cancels print notification when preparing with 0 remaining")
    func cancelPrintWhenPreparingNoTime() {
        let state = makeContentState(status: .preparing, remainingMinutes: 0)
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [], now: now)

        #expect(actions.contains(.cancel(identifier: "panda.print.finished")))
    }

    // MARK: - Drying Notification: Scheduling

    @Test("Schedules drying notification for drying AMS unit")
    func scheduleDryingNotification() {
        let state = makeContentState(status: .idle)
        let unit = makeAMSUnit(id: 0, dryTimeRemaining: 120, amsTypeName: "AMS")
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [unit], now: now)

        let expectedFire = now.addingTimeInterval(120 * 60)
        #expect(actions.contains(.schedule(
            identifier: "panda.drying.finished.ams0",
            title: "Drying Complete",
            body: "AMS 1 has finished drying.",
            fireDate: expectedFire
        )))
    }

    @Test("Includes AMS type name in drying notification body")
    func dryingBodyIncludesTypeName() {
        let state = makeContentState(status: .idle)
        let unit = makeAMSUnit(id: 1, dryTimeRemaining: 60, amsTypeName: "AMS 2 Pro")
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [unit], now: now)

        if case let .schedule(_, _, body, _) = actions.first(where: {
            if case let .schedule(id, _, _, _) = $0, id == "panda.drying.finished.ams1" { return true }
            return false
        }) {
            #expect(body.contains("AMS 2 Pro 2"))
        } else {
            Issue.record("Expected a schedule action for drying")
        }
    }

    @Test("Uses generic name when AMS type is nil")
    func dryingBodyGenericName() {
        let state = makeContentState(status: .idle)
        let unit = makeAMSUnit(id: 2, dryTimeRemaining: 60, amsTypeName: nil)
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [unit], now: now)

        if case let .schedule(_, _, body, _) = actions.first(where: {
            if case let .schedule(id, _, _, _) = $0, id == "panda.drying.finished.ams2" { return true }
            return false
        }) {
            #expect(body.contains("AMS 3"))
        } else {
            Issue.record("Expected a schedule action for drying")
        }
    }

    @Test("Handles multiple AMS units independently")
    func multipleAMSUnits() {
        let state = makeContentState(status: .idle)
        let units = [
            makeAMSUnit(id: 0, dryTimeRemaining: 120),
            makeAMSUnit(id: 1, dryTimeRemaining: 0),
            makeAMSUnit(id: 2, dryTimeRemaining: 60),
        ]
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: units, now: now)

        // Unit 0: scheduled, unit 1: cancelled, unit 2: scheduled
        let scheduleIds = actions.compactMap { action -> String? in
            if case let .schedule(id, _, _, _) = action { return id }
            return nil
        }
        let cancelIds = actions.compactMap { action -> String? in
            if case let .cancel(id) = action { return id }
            return nil
        }

        #expect(scheduleIds.contains("panda.drying.finished.ams0"))
        #expect(scheduleIds.contains("panda.drying.finished.ams2"))
        #expect(cancelIds.contains("panda.drying.finished.ams1"))
    }

    @Test("Drying fire date equals now + dryTimeRemaining * 60")
    func dryingFireDateAccuracy() {
        let state = makeContentState(status: .idle)
        let unit = makeAMSUnit(id: 0, dryTimeRemaining: 90)
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [unit], now: now)

        let expectedFire = now.addingTimeInterval(90 * 60)
        if case let .schedule(_, _, _, fireDate) = actions.first(where: {
            if case let .schedule(id, _, _, _) = $0, id == "panda.drying.finished.ams0" { return true }
            return false
        }) {
            #expect(fireDate == expectedFire)
        } else {
            Issue.record("Expected a schedule action for drying")
        }
    }

    // MARK: - Drying Notification: Cancellation

    @Test("Cancels drying notification when AMS unit stops drying")
    func cancelDryingWhenStopped() {
        let state = makeContentState(status: .idle)
        let unit = makeAMSUnit(id: 0, dryTimeRemaining: 0)
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [unit], now: now)

        #expect(actions.contains(.cancel(identifier: "panda.drying.finished.ams0")))
    }

    // MARK: - Settings Integration

    @Test("Cancels print notification when print type is disabled")
    func cancelPrintWhenDisabled() {
        NotificationSettings.setEnabled(.printFinished, enabled: false)
        defer { NotificationSettings.setEnabled(.printFinished, enabled: true) }

        let state = makeContentState(status: .printing, remainingMinutes: 60)
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: [], now: now)

        #expect(actions.contains(.cancel(identifier: "panda.print.finished")))
        let hasSchedule = actions.contains {
            if case let .schedule(id, _, _, _) = $0, id == "panda.print.finished" { return true }
            return false
        }
        #expect(hasSchedule == false, "Should not schedule when disabled")
    }

    @Test("Cancels all drying notifications when drying type is disabled")
    func cancelDryingWhenDisabled() {
        NotificationSettings.setEnabled(.dryingFinished, enabled: false)
        defer { NotificationSettings.setEnabled(.dryingFinished, enabled: true) }

        let state = makeContentState(status: .idle)
        let units = [
            makeAMSUnit(id: 0, dryTimeRemaining: 120),
            makeAMSUnit(id: 1, dryTimeRemaining: 60),
        ]
        let actions = NotificationEvaluator.evaluate(contentState: state, amsUnits: units, now: now)

        #expect(actions.contains(.cancel(identifier: "panda.drying.finished.ams0")))
        #expect(actions.contains(.cancel(identifier: "panda.drying.finished.ams1")))
    }
}

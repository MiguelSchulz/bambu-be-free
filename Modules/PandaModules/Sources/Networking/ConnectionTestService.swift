import Foundation
import PandaModels

public enum ConnectionTestService {
    /// Result of a connection test phase, produced by racing an async stream against a timeout.
    private enum PhaseResult<T: Sendable>: Sendable {
        case success(T)
        case timeout
    }

    /// Tests MQTT connectivity to a Bambu Lab printer.
    ///
    /// 1. Validates serial requirement based on printer model
    /// 2. Connects to the MQTT broker (6s timeout)
    /// 3. Waits for the first data message (5s timeout) to confirm the topic subscription works
    ///
    /// Returns `nil` on success, or a localized error string on failure.
    public static func testConnection(
        ip: String,
        accessCode: String,
        serial: String,
        printerModel: BambuPrinter?,
        mqttServiceFactory: @Sendable () -> any MQTTServiceProtocol = { PandaMQTTService() }
    ) async -> String? {
        // 1. Pre-flight: validate serial requirement
        if let model = printerModel, model.serialRequired, serial.isEmpty {
            return String(localized: "\(model.displayName) printers require a serial number. You can find it on the printer's Device tab in Settings.")
        }

        let service = mqttServiceFactory()
        service.connect(ip: ip, accessCode: accessCode, serial: serial)
        defer { service.disconnect() }

        // 2. Wait for MQTT broker connection
        let brokerResult = await raceWithTimeout(seconds: 6) { () -> MQTTConnectionState? in
            for await state in service.stateStream {
                switch state {
                case .connected, .error: return state
                default: continue
                }
            }
            return nil
        }

        switch brokerResult {
        case .success(.connected):
            break // proceed to phase 3
        case .success(.error):
            return String(localized: "Could not connect to the printer. Please check that the IP address and access code are correct, and that your iPhone is on the same network as the printer.")
        case .timeout, .success:
            return String(localized: "Connection timed out. Make sure the printer is turned on and that your iPhone is on the same network.")
        }

        // 3. Wait for the first data message to confirm topic subscription works
        let dataResult = await raceWithTimeout(seconds: 5) {
            for await _ in service.messageStream {
                return true
            }
            return false
        }

        switch dataResult {
        case .success(true):
            return nil
        case .success(false), .timeout:
            if serial.isEmpty {
                return String(localized: "Connected to the printer, but no data was received. This printer may require a serial number. Please enter the serial number and try again.")
            }
            return String(localized: "Connected to the printer, but no data was received. The serial number may be incorrect — please double-check it on the printer's Device tab in Settings.")
        }
    }

    // MARK: - Helpers

    /// Races an async operation against a timeout. Returns `.success` if the operation
    /// completes first, or `.timeout` if the deadline expires.
    private static func raceWithTimeout<T: Sendable>(
        seconds: Int,
        operation: @escaping @Sendable () async -> T
    ) async -> PhaseResult<T> {
        await withTaskGroup(of: PhaseResult<T>.self) { group in
            group.addTask {
                await .success(operation())
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return .timeout
            }
            let result = await group.next() ?? .timeout
            group.cancelAll()
            return result
        }
    }
}

import CocoaMQTT
import Foundation
import PandaLogger
import PandaModels

private let logCategory = "MQTT"

public final class PandaMQTTService: MQTTServiceProtocol, @unchecked Sendable {
    private var mqtt: CocoaMQTT?
    private var serialNumber: String?
    private var publishTopic: String?
    private let delegateHandler = DelegateHandler()
    private var lastPayload: PandaMQTTPayload?

    public private(set) var connectionState: MQTTConnectionState = .disconnected

    // Continuations are set up eagerly in init so they're ready before connect()
    private var stateContinuation: AsyncStream<MQTTConnectionState>.Continuation?
    private var messageContinuation: AsyncStream<PandaMQTTPayload>.Continuation?

    public let stateStream: AsyncStream<MQTTConnectionState>
    public let messageStream: AsyncStream<PandaMQTTPayload>

    public init() {
        let (stateStream, stateContinuation) = AsyncStream.makeStream(
            of: MQTTConnectionState.self, bufferingPolicy: .bufferingNewest(1)
        )
        self.stateStream = stateStream
        self.stateContinuation = stateContinuation
        stateContinuation.onTermination = { _ in
            appLog(.info, category: logCategory, "State stream terminated")
        }

        let (messageStream, messageContinuation) = AsyncStream.makeStream(
            of: PandaMQTTPayload.self, bufferingPolicy: .bufferingNewest(64)
        )
        self.messageStream = messageStream
        self.messageContinuation = messageContinuation
        messageContinuation.onTermination = { _ in
            appLog(.info, category: logCategory, "Message stream terminated")
        }
    }

    public func connect(ip: String, accessCode: String, serial: String) {
        disconnect()

        let hasSerial = !serial.isEmpty
        if hasSerial {
            serialNumber = serial
            publishTopic = "device/\(serial)/request"
        }

        appLog(.info, category: logCategory, "Connecting to \(ip):8883... serial: \(hasSerial ? "provided" : "auto-discover")")

        let clientId = "PandaBeFree_\(Int(Date.now.timeIntervalSince1970))"
        let client = CocoaMQTT(clientID: clientId, host: ip, port: 8883)
        client.username = "bblp"
        client.password = accessCode
        client.enableSSL = true
        client.allowUntrustCACertificate = true
        client.keepAlive = 60

        // Disable hostname verification — the printer's self-signed cert CN
        // is the serial number, not the IP address
        client.sslSettings = [
            kCFStreamSSLPeerName as String: "" as NSString,
        ]

        client.delegate = delegateHandler

        // Accept the printer's self-signed certificate (signed by "BBL CA")
        client.didReceiveTrust = { _, _, completionHandler in
            appLog(.info, category: logCategory, "Trust evaluation — accepting self-signed certificate")
            completionHandler(true)
        }

        let reportTopic = hasSerial ? "device/\(serial)/report" : "device/+/report"
        delegateHandler.onConnected = { [weak self] mqtt in
            appLog(.info, category: logCategory, "Connected! Subscribing to \(reportTopic)")
            self?.connectionState = .connected
            self?.stateContinuation?.yield(.connected)
            mqtt.subscribe(reportTopic)
            if hasSerial {
                self?.sendCommand(.pushAll)
                self?.sendCommand(.getVersion)
            }
        }

        delegateHandler.onDisconnected = { [weak self] in
            appLog(.info, category: logCategory, "Disconnected")
            self?.connectionState = .disconnected
            self?.stateContinuation?.yield(.disconnected)
        }

        delegateHandler.onError = { [weak self] message in
            appLog(.error, category: logCategory, "Connection error: \(message)")
            self?.connectionState = .error(message)
            self?.stateContinuation?.yield(.error(message))
        }

        delegateHandler.onMessage = { [weak self] topic, data in
            // Auto-discover serial number from topic: device/{SERIAL}/report
            if self?.serialNumber == nil {
                let parts = topic.split(separator: "/")
                if parts.count == 3, parts[0] == "device", parts[2] == "report" {
                    let discovered = String(parts[1])
                    SessionLogger.shared.addRedaction(discovered, placeholder: "[SERIAL]")
                    appLog(.info, category: logCategory, "Discovered serial: \(discovered)")
                    self?.serialNumber = discovered
                    self?.publishTopic = "device/\(discovered)/request"
                    self?.sendCommand(.pushAll)
                    self?.sendCommand(.getVersion)
                }
            }

            if let payload = PandaMQTTPayload.parse(from: data) {
                // Log only changed fields to keep the log compact
                let diff = Self.payloadDiff(old: self?.lastPayload, new: payload)
                self?.lastPayload = payload
                if let diff {
                    appLog(.info, category: logCategory, "Received on \(topic): \(diff)")
                }
                self?.messageContinuation?.yield(payload)
            } else {
                let rawJSON = String(data: data, encoding: .utf8) ?? "(binary, \(data.count) bytes)"
                appLog(.warning, category: logCategory, "Failed to parse MQTT payload: \(rawJSON)")
            }
        }

        connectionState = .connecting
        stateContinuation?.yield(.connecting)
        self.mqtt = client
        let result = client.connect()
        appLog(.info, category: logCategory, "connect() returned: \(result)")
    }

    public func disconnect() {
        mqtt?.disconnect()
        mqtt?.delegate = nil
        mqtt = nil
        serialNumber = nil
        publishTopic = nil
        lastPayload = nil
        connectionState = .disconnected
    }

    public func sendCommand(_ command: PrinterCommand) {
        guard let mqtt, let topic = publishTopic else { return }
        let data = command.payload()
        guard let jsonString = String(data: data, encoding: .utf8) else { return }
        appLog(.info, category: logCategory, "Sending to \(topic): \(jsonString)")
        mqtt.publish(topic, withString: jsonString, qos: .qos1)
    }

    // MARK: - Payload Diff

    /// Compares two payloads field-by-field and returns a compact string of changes.
    /// Returns nil if nothing meaningful changed.
    private static func payloadDiff(old: PandaMQTTPayload?, new: PandaMQTTPayload) -> String? {
        var changes: [String] = []

        func track(_ name: String, old: String?, new: String?) {
            guard let new, new != old else { return }
            changes.append("\(name): \(new)")
        }

        func track(_ name: String, old: Int?, new: Int?) {
            guard let new, new != old else { return }
            changes.append("\(name): \(new)")
        }

        func track(_ name: String, old: Bool?, new: Bool?) {
            guard let new, new != old else { return }
            changes.append("\(name): \(new)")
        }

        func trackTemp(_ name: String, old: Double?, new: Double?) {
            guard let new else { return }
            // Suppress jitter < 0.5
            if let old, abs(new - old) < 0.5 { return }
            changes.append("\(name): \(new)")
        }

        func trackFan(_ name: String, old: Int?, new: Int?) {
            guard let new else { return }
            // Suppress jitter ≤26 on 0-255 scale (≈ ±1 step on the raw 0-15 sensor scale)
            if let old, abs(new - old) <= 26 { return }
            changes.append("\(name): \(new)")
        }

        let o = old ?? PandaMQTTPayload()

        track("gcode_state", old: o.gcodeState, new: new.gcodeState)
        track("mc_percent", old: o.mcPercent, new: new.mcPercent)
        track("mc_remaining_time", old: o.mcRemainingTime, new: new.mcRemainingTime)
        track("subtask_name", old: o.subtaskName, new: new.subtaskName)
        track("stg_cur", old: o.stgCur, new: new.stgCur)
        track("layer_num", old: o.layerNum, new: new.layerNum)
        track("total_layer_num", old: o.totalLayerNum, new: new.totalLayerNum)
        track("home_flag", old: o.homeFlag, new: new.homeFlag)
        track("chamber_light", old: o.chamberLightOn, new: new.chamberLightOn)
        track("airduct_mode", old: o.airductMode, new: new.airductMode)
        track("tray_now", old: o.trayNow, new: new.trayNow)

        trackTemp("nozzle_temper", old: o.nozzleTemper, new: new.nozzleTemper)
        trackTemp("nozzle_target", old: o.nozzleTargetTemper, new: new.nozzleTargetTemper)
        trackTemp("bed_temper", old: o.bedTemper, new: new.bedTemper)
        trackTemp("bed_target", old: o.bedTargetTemper, new: new.bedTargetTemper)
        trackTemp("chamber_temper", old: o.chamberTemper, new: new.chamberTemper)

        trackFan("part_fan", old: o.partFanSpeed, new: new.partFanSpeed)
        trackFan("aux_fan", old: o.auxFanSpeed, new: new.auxFanSpeed)
        trackFan("chamber_fan", old: o.chamberFanSpeed, new: new.chamberFanSpeed)
        trackFan("heatbreak_fan", old: o.heatbreakFanSpeed, new: new.heatbreakFanSpeed)

        if new.amsUnits != nil, new.amsUnits?.count != o.amsUnits?.count {
            changes.append("ams_units: \(new.amsUnits?.count ?? 0) units")
        }

        if let modules = new.amsModuleVersions, modules != o.amsModuleVersions {
            changes.append("ams_module_versions updated")
        }

        if changes.isEmpty { return nil }
        return changes.joined(separator: ", ")
    }
}

// MARK: - Delegate Handler

/// Bridges CocoaMQTT delegate callbacks to closures.
private class DelegateHandler: CocoaMQTTDelegate {
    var onConnected: ((CocoaMQTT) -> Void)?
    var onDisconnected: (() -> Void)?
    var onError: ((String) -> Void)?
    var onMessage: ((String, Data) -> Void)?

    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        appLog(.info, category: logCategory, "didConnectAck: \(String(describing: ack))")
        if ack == .accept {
            onConnected?(mqtt)
        } else {
            let message = switch ack {
            case .badUsernameOrPassword: "Invalid access code"
            case .notAuthorized: "Not authorized"
            default: "Connection rejected: \(ack)"
            }
            onError?(message)
        }
    }

    func mqtt(_: CocoaMQTT, didPublishMessage _: CocoaMQTTMessage, id _: UInt16) {}
    func mqtt(_: CocoaMQTT, didPublishAck _: UInt16) {}

    func mqtt(_: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id _: UInt16) {
        guard let data = message.string?.data(using: .utf8) else { return }
        onMessage?(message.topic, data)
    }

    func mqtt(_: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        appLog(.info, category: logCategory, "Subscribed — success: \(success.count) topics, failed: \(failed)")
    }

    func mqtt(_: CocoaMQTT, didUnsubscribeTopics _: [String]) {}

    func mqttDidPing(_: CocoaMQTT) {}
    func mqttDidReceivePong(_: CocoaMQTT) {}

    func mqttDidDisconnect(_: CocoaMQTT, withError err: (any Error)?) {
        appLog(err != nil ? .error : .info, category: logCategory, "mqttDidDisconnect, error: \(err?.localizedDescription ?? "none")")
        if let err {
            let message = err.localizedDescription
            onError?(message)
        } else {
            onDisconnected?()
        }
    }
}

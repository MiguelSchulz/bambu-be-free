import Foundation
import os
import PandaModels
import Synchronization

// MARK: - Log Level

public enum LogLevel: String, Sendable {
    case info
    case warning
    case error

    public var emoji: String {
        switch self {
        case .info: "\u{2139}\u{FE0F}"
        case .warning: "\u{26A0}\u{FE0F}"
        case .error: "\u{1F534}"
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .info: .info
        case .warning: .default
        case .error: .error
        }
    }
}

// MARK: - Log Entry

public struct LogEntry: Sendable {
    public let timestamp: Date
    public let level: LogLevel
    public let category: String
    public let message: String

    public init(timestamp: Date = .now, level: LogLevel, category: String, message: String) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
    }
}

// MARK: - Session Logger

/// Thread-safe in-memory logger.
/// Uses `Mutex` for state protection and `Atomic` for the pause flag.
/// All read methods are `@concurrent` to guarantee they never run on MainActor.
public final class SessionLogger: Sendable {
    public static let shared = SessionLogger()

    private struct State: ~Copyable {
        var entries: [LogEntry] = []
        var redactions: [String: String] = [:]
    }

    private let state = Mutex(State())
    private let maxEntries = 10000
    private let osLoggers = Mutex<[String: Logger]>([:])
    private let _paused = Atomic<Bool>(false)

    /// When true, `log()` calls skip storing entries.
    public var isPaused: Bool {
        _paused.load(ordering: .relaxed)
    }

    public func pause() {
        _paused.store(true, ordering: .relaxed)
    }

    public func resume() {
        _paused.store(false, ordering: .relaxed)
    }

    // MARK: - Writing (synchronous, any thread)

    /// Log a message. Synchronous and safe to call from any thread.
    /// Skipped when the logger is paused.
    public func log(_ level: LogLevel, category: String, _ message: String) {
        guard !isPaused else { return }

        let sanitized = state.withLock { s in
            redact(message, using: &s)
        }

        let entry = LogEntry(level: level, category: category, message: sanitized)

        state.withLock { s in
            s.entries.append(entry)
            if s.entries.count > maxEntries {
                s.entries.removeFirst(s.entries.count - maxEntries)
            }
        }

        let logger = osLogger(for: category)
        logger.log(level: level.osLogType, "\(level.emoji) [\(category)] \(message)")
    }

    /// Register an additional string to redact from all future log messages.
    public func addRedaction(_ value: String, placeholder: String) {
        guard !value.isEmpty else { return }
        state.withLock { s in
            s.redactions[value] = placeholder
        }
    }

    // MARK: - Reading (@concurrent — always off MainActor)

    /// Current number of entries. Synchronous — safe for UI polling.
    public func entryCount() -> Int {
        state.withLock { $0.entries.count }
    }

    /// Formats the last `count` entries for UI preview.
    /// Runs entirely off the main thread.
    @concurrent
    public func formattedPreview(lastEntries count: Int = 50) async -> String {
        let (entries, total) = state.withLock { s in
            let total = s.entries.count
            let tail = total > count ? Array(s.entries.suffix(count)) : s.entries
            return (tail, total)
        }
        let model = SharedSettings.printerModel
        let prefix = total > count
            ? "... (\(total - count) earlier entries omitted, included in export)\n\n"
            : ""
        return prefix + Self.formatEntries(entries, total: total, printerModel: model)
    }

    /// Formats all entries as an exportable log string.
    /// Runs entirely off the main thread.
    @concurrent
    public func formattedLog(printerModel: BambuPrinter? = nil) async -> String {
        let entries = state.withLock { s in Array(s.entries) }
        let model = printerModel ?? SharedSettings.printerModel
        return Self.formatEntries(entries, total: entries.count, printerModel: model)
    }

    /// Snapshot all entries. For testing.
    @concurrent
    public func snapshotEntries() async -> [LogEntry] {
        state.withLock { Array($0.entries) }
    }

    /// Reset all entries and redactions. For testing.
    public func reset() {
        state.withLock { s in
            s.entries.removeAll()
            s.redactions.removeAll()
        }
    }

    // MARK: - Private

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let headerDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "y-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func osLogger(for category: String) -> Logger {
        osLoggers.withLock { cache in
            if let existing = cache[category] {
                return existing
            }
            let logger = Logger(subsystem: "PandaBeFree", category: category)
            cache[category] = logger
            return logger
        }
    }

    // swiftformat:disable:next nonisolatedUnsafe
    private nonisolated(unsafe) static let snPattern = try! Regex(#""sn"\s*:\s*"[^"]*""#)

    private func redact(_ message: String, using state: inout State) -> String {
        var result = message

        let accessCode = SharedSettings.printerAccessCode
        if !accessCode.isEmpty, result.contains(accessCode) {
            result = result.replacing(accessCode, with: "[REDACTED]")
        }

        let serial = SharedSettings.printerSerial
        if !serial.isEmpty, result.contains(serial) {
            result = result.replacing(serial, with: "[SERIAL]")
        }

        for (value, placeholder) in state.redactions {
            if result.contains(value) {
                result = result.replacing(value, with: placeholder)
            }
        }

        // Redact any "sn": "..." values in JSON responses
        if result.contains("\"sn\"") {
            result = result.replacing(Self.snPattern, with: "\"sn\": \"[SERIAL]\"")
        }

        return result
    }

    /// Pure formatting function. No locks, no MainActor. Safe to call from any thread.
    private static func formatEntries(
        _ entries: [LogEntry],
        total: Int,
        printerModel: BambuPrinter?
    ) -> String {
        var lines: [String] = []
        lines.reserveCapacity(entries.count + 10)

        lines.append("PandaBeFree Session Log")
        lines.append("=======================")
        lines.append("Date: \(headerDateFormatter.string(from: .now))")
        lines.append("iOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        {
            lines.append("App: \(version) (\(build))")
        }

        if let model = printerModel {
            lines.append("Printer: \(model.displayName)")
        }

        lines.append("Total entries: \(total)")
        lines.append("")
        lines.append("---")
        lines.append("")

        for entry in entries {
            let time = timestampFormatter.string(from: entry.timestamp)
            lines.append("\(time) \(entry.level.emoji) [\(entry.category)] \(entry.message)")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Convenience Global Function

/// Fire-and-forget log call. Synchronous, safe from any thread.
public func appLog(_ level: LogLevel, category: String, _ message: String) {
    SessionLogger.shared.log(level, category: category, message)
}

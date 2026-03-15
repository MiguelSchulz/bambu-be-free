import PandaLogger
import PandaModels
import Testing

@Suite("SessionLogger")
struct SessionLoggerTests {
    let logger = SessionLogger.shared

    init() {
        logger.reset()
    }

    @Test func storesLogEntries() async {
        logger.log(.info, category: "Test", "Hello")
        logger.log(.warning, category: "Test", "Watch out")
        logger.log(.error, category: "Test", "Something broke")

        let entries = await logger.snapshotEntries()
        #expect(entries.count == 3)
        #expect(entries[0].level == .info)
        #expect(entries[0].category == "Test")
        #expect(entries[0].message == "Hello")
        #expect(entries[1].level == .warning)
        #expect(entries[2].level == .error)
    }

    @Test func capsEntriesAtMaximum() async {
        for i in 0..<10005 {
            logger.log(.info, category: "Bulk", "Entry \(i)")
        }

        let entries = await logger.snapshotEntries()
        #expect(entries.count == 10000)
        #expect(entries[0].message == "Entry 5")
        #expect(entries[entries.count - 1].message == "Entry 10004")
    }

    @Test(arguments: [
        (LogLevel.info, "\u{2139}\u{FE0F}"),
        (LogLevel.warning, "\u{26A0}\u{FE0F}"),
        (LogLevel.error, "\u{1F534}"),
    ])
    func emojiMapping(level: LogLevel, expectedEmoji: String) {
        #expect(level.emoji == expectedEmoji)
    }

    @Test func formattedLogIncludesHeader() async {
        logger.log(.info, category: "MQTT", "Connected")

        let output = await logger.formattedLog()

        #expect(output.contains("PandaBeFree Session Log"))
        #expect(output.contains("======================="))
        #expect(output.contains("iOS:"))
        #expect(output.contains("---"))
    }

    @Test func formattedLogIncludesEntries() async {
        logger.log(.info, category: "MQTT", "Connected to printer")
        logger.log(.error, category: "Camera", "Stream failed")

        let output = await logger.formattedLog()

        #expect(output.contains("[MQTT] Connected to printer"))
        #expect(output.contains("[Camera] Stream failed"))
        #expect(output.contains(LogLevel.info.emoji))
        #expect(output.contains(LogLevel.error.emoji))
    }

    @Test func formattedLogIncludesPrinterModel() async {
        let output = await logger.formattedLog(printerModel: .p1s)
        #expect(output.contains("Printer: Bambu Lab P1S"))
    }

    @Test func redactsAccessCode() async throws {
        let originalCode = SharedSettings.printerAccessCode
        SharedSettings.printerAccessCode = "secret123"
        defer { SharedSettings.printerAccessCode = originalCode }

        logger.log(.info, category: "Test", "Password is secret123 here")

        let entries = await logger.snapshotEntries()
        let entry = try #require(entries.last)
        #expect(entry.message == "Password is [REDACTED] here")
        #expect(entry.message.contains("secret123") == false)
    }

    @Test func redactionSkipsWhenNoAccessCode() async throws {
        let originalCode = SharedSettings.printerAccessCode
        SharedSettings.printerAccessCode = ""
        defer { SharedSettings.printerAccessCode = originalCode }

        logger.log(.info, category: "Test", "No code to redact")

        let entries = await logger.snapshotEntries()
        let entry = try #require(entries.last)
        #expect(entry.message == "No code to redact")
    }

    @Test func redactsSerialNumber() async throws {
        let originalSerial = SharedSettings.printerSerial
        SharedSettings.printerSerial = "01P00A000000001"
        defer { SharedSettings.printerSerial = originalSerial }

        logger.log(.info, category: "Test", "Subscribing to device/01P00A000000001/report")

        let entries = await logger.snapshotEntries()
        let entry = try #require(entries.last)
        #expect(entry.message == "Subscribing to device/[SERIAL]/report")
        #expect(entry.message.contains("01P00A000000001") == false)
    }

    @Test func resetClearsAllEntries() async {
        logger.log(.info, category: "Test", "Entry 1")
        logger.log(.info, category: "Test", "Entry 2")
        logger.reset()

        let count = await logger.entryCount()
        #expect(count == 0)
    }

    @Test func timestampFormattingInOutput() async throws {
        logger.log(.info, category: "MQTT", "Test message")

        let output = await logger.formattedLog()
        let lines = output.components(separatedBy: "\n")
        let entryLine = try #require(lines.last { $0.contains("[MQTT]") })

        let timePattern = #/\d{2}:\d{2}:\d{2}\.\d{3}/#
        #expect(entryLine.contains(timePattern))
    }

    @Test func logEntryPreservesCategory() async {
        logger.log(.info, category: "Camera", "Frame received")
        logger.log(.warning, category: "MQTT", "Reconnecting")

        let entries = await logger.snapshotEntries()
        #expect(entries[0].category == "Camera")
        #expect(entries[1].category == "MQTT")
    }
}

import Foundation
@testable import PandaModels
import Testing

@Suite("Bambu Printer Model")
struct BambuPrinterTests {
    @Test("All 12 printer models exist")
    func allModelsExist() {
        #expect(BambuPrinter.allCases.count == 12)
    }

    @Test("Printer families contain correct models",
          arguments: [
              (PrinterFamily.x1, [BambuPrinter.x1, .x1c, .x1e]),
              (PrinterFamily.p1, [BambuPrinter.p1p, .p1s]),
              (PrinterFamily.p2, [BambuPrinter.p2s]),
              (PrinterFamily.a1, [BambuPrinter.a1, .a1Mini]),
              (PrinterFamily.h2, [BambuPrinter.h2c, .h2d, .h2dPro, .h2s]),
          ])
    func familyModels(family: PrinterFamily, expected: [BambuPrinter]) {
        #expect(family.models == expected)
    }

    @Test("All families are covered")
    func allFamiliesCovered() {
        #expect(PrinterFamily.allCases.count == 5)
    }

    @Test("RTSP camera protocol printers",
          arguments: [BambuPrinter.x1, .x1c, .x1e, .p2s, .h2c, .h2d, .h2dPro, .h2s])
    func rtspProtocol(printer: BambuPrinter) {
        #expect(printer.cameraProtocol == .rtsp)
    }

    @Test("TCP camera protocol printers",
          arguments: [BambuPrinter.p1p, .p1s, .a1, .a1Mini])
    func tcpProtocol(printer: BambuPrinter) {
        #expect(printer.cameraProtocol == .tcp)
    }

    @Test("Serial required only for A1 and A1 Mini",
          arguments: BambuPrinter.allCases)
    func serialRequired(printer: BambuPrinter) {
        let expected = printer == .a1 || printer == .a1Mini
        #expect(printer.serialRequired == expected)
    }

    @Test("Chamber temperature support",
          arguments: [
              (BambuPrinter.x1, true),
              (BambuPrinter.x1c, true),
              (BambuPrinter.x1e, true),
              (BambuPrinter.p1p, false),
              (BambuPrinter.p1s, false),
              (BambuPrinter.p2s, true),
              (BambuPrinter.a1, false),
              (BambuPrinter.a1Mini, false),
              (BambuPrinter.h2c, true),
              (BambuPrinter.h2d, true),
              (BambuPrinter.h2dPro, true),
              (BambuPrinter.h2s, true),
          ])
    func chamberTemp(printer: BambuPrinter, expected: Bool) {
        #expect(printer.hasChamberTemp == expected)
    }

    @Test("Aux fan support",
          arguments: [
              (BambuPrinter.a1, false),
              (BambuPrinter.a1Mini, false),
              (BambuPrinter.x1c, true),
              (BambuPrinter.p1s, true),
              (BambuPrinter.p2s, true),
              (BambuPrinter.h2d, true),
          ])
    func auxFan(printer: BambuPrinter, expected: Bool) {
        #expect(printer.hasAuxFan == expected)
    }

    @Test("Airduct support only for P2S")
    func airductSupport() {
        #expect(BambuPrinter.p2s.hasAirduct)
        for printer in BambuPrinter.allCases where printer != .p2s {
            #expect(printer.hasAirduct == false)
        }
    }

    @Test("Dual nozzle support",
          arguments: [
              (BambuPrinter.h2c, true),
              (BambuPrinter.h2d, true),
              (BambuPrinter.h2dPro, true),
              (BambuPrinter.h2s, false),
              (BambuPrinter.x1c, false),
              (BambuPrinter.a1, false),
          ])
    func dualNozzle(printer: BambuPrinter, expected: Bool) {
        #expect(printer.hasDualNozzle == expected)
    }

    @Test("All printers have non-empty display names", arguments: BambuPrinter.allCases)
    func displayNames(printer: BambuPrinter) {
        #expect(!printer.displayName.isEmpty)
    }

    @Test("All families have non-empty display names", arguments: PrinterFamily.allCases)
    func familyDisplayNames(family: PrinterFamily) {
        #expect(!family.displayName.isEmpty)
    }

    @Test("Family assignment is correct for all printers", arguments: BambuPrinter.allCases)
    func familyAssignment(printer: BambuPrinter) {
        #expect(printer.family.models.contains(printer))
    }

    @Test("Codable round-trip", arguments: BambuPrinter.allCases)
    func codableRoundTrip(printer: BambuPrinter) throws {
        let data = try JSONEncoder().encode(printer)
        let decoded = try JSONDecoder().decode(BambuPrinter.self, from: data)
        #expect(decoded == printer)
    }
}

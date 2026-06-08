import Testing
import Foundation
@testable import SadaaCore

@Suite struct CostTests {
    @Test func testEstimateAddsTranscriptionAndFormatter() {
        // 120s at $0.006/min = $0.012; 2000 chars at $0.002/1k = $0.004; total $0.016.
        let cost = CostEstimator.estimate(
            durationSeconds: 120, transcriptionRatePerMinute: 0.006,
            characters: 2000, formatterRatePer1kChars: 0.002)
        #expect(abs(cost - 0.016) < 1e-9)
    }

    @Test func testEstimateHandlesNilDuration() {
        let cost = CostEstimator.estimate(
            durationSeconds: nil, transcriptionRatePerMinute: 0.006,
            characters: 1000, formatterRatePer1kChars: 0.002)
        #expect(abs(cost - 0.002) < 1e-9)
    }

    @Test func testWithEstimatedCostCopiesFields() {
        let base = DictationRecord(text: "hi", createdAt: Date(), language: "english",
                                   provider: "Azure OpenAI", durationSeconds: 3)
        let costed = base.withEstimatedCost(0.01)
        #expect(costed.id == base.id)
        #expect(costed.text == "hi")
        #expect(costed.provider == "Azure OpenAI")
        #expect(costed.durationSeconds == 3)
        #expect(costed.estimatedCost == 0.01)
    }

    @Test func testRecordCodableRoundTripWithCost() throws {
        let record = DictationRecord(text: "x", createdAt: Date(), language: nil,
                                     provider: "OpenAI", durationSeconds: 1,
                                     estimatedCost: 0.005)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(DictationRecord.self, from: data)
        #expect(decoded == record)
    }

    @Test func testMonthlyTotalsFiltersByMonth() {
        var components = DateComponents()
        components.year = 2026; components.month = 6; components.day = 8
        let cal = Calendar(identifier: .gregorian)
        let now = cal.date(from: components)!
        let lastMonth = cal.date(byAdding: .month, value: -1, to: now)!

        let inMonth = DictationRecord(text: "a", createdAt: now, language: nil,
                                      provider: "p", durationSeconds: 60, estimatedCost: 0.01)
        let outMonth = DictationRecord(text: "b", createdAt: lastMonth, language: nil,
                                       provider: "p", durationSeconds: 120, estimatedCost: 0.02)

        let totals = CostMeter.monthlyTotals(records: [inMonth, outMonth], now: now, calendar: cal)
        #expect(abs(totals.minutes - 1.0) < 1e-9)
        #expect(abs(totals.cost - 0.01) < 1e-9)
    }
}

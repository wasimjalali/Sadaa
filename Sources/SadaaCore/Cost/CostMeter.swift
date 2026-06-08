import Foundation

/// Aggregates dictation history into a monthly minutes + estimated spend figure.
/// Spec section 7.
public enum CostMeter {
    public struct Totals: Equatable, Sendable {
        public let minutes: Double
        public let cost: Double

        public init(minutes: Double, cost: Double) {
            self.minutes = minutes
            self.cost = cost
        }
    }

    /// Sums minutes and estimated cost for records that fall in `now`'s month.
    public static func monthlyTotals(records: [DictationRecord], now: Date,
                                     calendar: Calendar = .current) -> Totals {
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        var minutes = 0.0
        var cost = 0.0
        for record in records {
            guard calendar.component(.month, from: record.createdAt) == month,
                  calendar.component(.year, from: record.createdAt) == year else { continue }
            minutes += (record.durationSeconds ?? 0) / 60
            cost += record.estimatedCost ?? 0
        }
        return Totals(minutes: minutes, cost: cost)
    }
}

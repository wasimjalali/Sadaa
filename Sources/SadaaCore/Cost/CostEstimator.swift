import Foundation

/// Rough per-dictation cost. Spec section 7: credit awareness, not accounting.
public enum CostEstimator {
    /// Transcription (duration-based) plus a formatter character estimate, in dollars.
    public static func estimate(durationSeconds: Double?,
                                transcriptionRatePerMinute: Double,
                                characters: Int,
                                formatterRatePer1kChars: Double) -> Double {
        let minutes = (durationSeconds ?? 0) / 60
        let transcription = minutes * transcriptionRatePerMinute
        let formatter = Double(characters) / 1000 * formatterRatePer1kChars
        return transcription + formatter
    }
}

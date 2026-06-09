import Foundation

/// Synthesizes the soft start/stop dictation cues and encodes them as
/// in-memory WAV data. Pure and testable; playback lives in the app layer.
/// Both cues are built from the same two notes a fifth apart (C5 and G5) so
/// they read as one family: the start cue rises, the stop cue falls.
public enum ChimeSynth {
    static let sampleRate = 44_100.0
    static let lowNote = 523.25    // C5
    static let highNote = 783.99   // G5

    public static func startChime() -> Data {
        wavData(samples: chime(frequencies: [lowNote, highNote]))
    }

    public static func stopChime() -> Data {
        wavData(samples: chime(frequencies: [highNote, lowNote]))
    }

    /// Renders the notes in order, each with a soft attack and a long decay,
    /// overlapping slightly so the pair reads as one smooth gesture. A quiet
    /// octave harmonic warms the plain sine.
    static func chime(frequencies: [Double],
                      noteDuration: Double = 0.18,
                      overlap: Double = 0.06,
                      amplitude: Double = 0.25) -> [Int16] {
        let noteSamples = Int(noteDuration * sampleRate)
        let stepSamples = Int((noteDuration - overlap) * sampleRate)
        let length = stepSamples * (frequencies.count - 1) + noteSamples
        var mix = [Double](repeating: 0, count: length)

        for (index, frequency) in frequencies.enumerated() {
            let offset = stepSamples * index
            for n in 0..<noteSamples {
                let t = Double(n) / sampleRate
                let value = sin(2 * .pi * frequency * t)
                          + 0.15 * sin(2 * .pi * frequency * 2 * t)
                mix[offset + n] += amplitude * envelope(at: t, duration: noteDuration) * value
            }
        }
        return mix.map { Int16(max(-1, min(1, $0)) * 32_767) }
    }

    /// 10 ms linear attack, exponential decay, 12 ms linear release, so the
    /// cue never clicks on either edge.
    private static func envelope(at t: Double, duration: Double) -> Double {
        let rise = min(t / 0.010, 1)
        let fall = min(max(duration - t, 0) / 0.012, 1)
        return rise * fall * exp(-6 * t)
    }

    /// Standard 44-byte WAV header (PCM, mono, 16-bit) plus the samples.
    static func wavData(samples: [Int16], sampleRate: Int = 44_100) -> Data {
        var data = Data()
        func append32(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        func append16(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        let dataBytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8))
        append32(36 + dataBytes)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append32(16)                       // fmt chunk size
        append16(1)                        // PCM
        append16(1)                        // mono
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * 2))   // byte rate
        append16(2)                        // block align
        append16(16)                       // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append32(dataBytes)
        for sample in samples {
            withUnsafeBytes(of: sample.littleEndian) { data.append(contentsOf: $0) }
        }
        return data
    }
}

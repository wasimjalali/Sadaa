import AVFoundation
import Foundation

public protocol AudioRecording: AnyObject {
    func start(to url: URL) throws
    func stop() throws -> URL
    func cancel()
    var onLevel: ((Float) -> Void)? { get set }
    var onAutoStop: (() -> Void)? { get set }
}

public enum AudioRecorderError: Error {
    case notRecording
    case formatUnsupported
}

/// AVAudioEngine capture -> 16kHz mono Int16 WAV. UI-facing callbacks fire
/// on the real-time tap thread; the app layer hops to the main thread.
///
/// Threading: AVAudioEngine drives the input tap on a high-priority real-time
/// render thread. A synchronous FileHandle write there can glitch audio, so the
/// WavWriter is owned by a dedicated serial queue. The tap does only the cheap
/// work (RMS, watchdog, Int16 conversion) and hands the converted samples to the
/// queue. The writer is created, appended to and finished only on that queue, so
/// there is no data race on it.
public final class AudioRecorder: AudioRecording {
    private let engine = AVAudioEngine()
    private var writer: WavWriter?
    private var fileURL: URL?
    private var watchdog: SilenceWatchdog
    private var startedAt: Date?
    private let silenceTimeout: TimeInterval
    /// Hard cap on recording length. Spec section 8: 10 minutes.
    private let maxDuration: TimeInterval

    /// Serial queue that exclusively owns the WavWriter. All create/append/finish
    /// calls happen here so the real-time tap thread never blocks on file I/O.
    private let writerQueue = DispatchQueue(label: "com.sadaa.audiorecorder.writer")

    public var onLevel: ((Float) -> Void)?
    /// Fires when silence timeout or max duration is hit; the app layer
    /// treats it exactly like a stop toggle.
    public var onAutoStop: (() -> Void)?

    public init(silenceTimeout: TimeInterval = 60,
                maxDuration: TimeInterval = 600) {
        self.silenceTimeout = silenceTimeout
        self.maxDuration = maxDuration
        self.watchdog = SilenceWatchdog(timeout: silenceTimeout)
    }

    public func start(to url: URL) throws {
        let input = engine.inputNode
        let hwFormat = input.outputFormat(forBus: 0)
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                               sampleRate: 16_000, channels: 1,
                                               interleaved: true),
              let converter = AVAudioConverter(from: hwFormat, to: targetFormat)
        else { throw AudioRecorderError.formatUnsupported }

        // Create the writer on the serial queue so it's owned there from birth.
        var writerError: Error?
        writerQueue.sync {
            do {
                self.writer = try WavWriter(url: url, sampleRate: 16_000)
            } catch {
                writerError = error
            }
        }
        if let writerError { throw writerError }

        fileURL = url
        watchdog = SilenceWatchdog(timeout: silenceTimeout)
        startedAt = Date()

        input.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) {
            [weak self] buffer, _ in
            self?.process(buffer: buffer, converter: converter,
                          targetFormat: targetFormat)
        }
        engine.prepare()
        try engine.start()
    }

    public func stop() throws -> URL {
        guard let url = fileURL else { throw AudioRecorderError.notRecording }
        teardownEngine()
        // Finish synchronously on the writer queue so any in-flight appends
        // already enqueued by the tap run first and the file is fully flushed
        // before we return the URL.
        var finishError: Error?
        writerQueue.sync {
            do {
                try self.writer?.finish()
            } catch {
                finishError = error
            }
            self.writer = nil
        }
        fileURL = nil
        if let finishError { throw finishError }
        return url
    }

    public func cancel() {
        teardownEngine()
        let url = fileURL
        writerQueue.sync {
            try? self.writer?.finish()
            self.writer = nil
        }
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
        fileURL = nil
    }

    private func teardownEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func process(buffer: AVAudioPCMBuffer,
                         converter: AVAudioConverter,
                         targetFormat: AVAudioFormat) {
        // RMS from the float hardware buffer for HUD levels + silence detection.
        var rms: Float = 0
        if let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 {
            let n = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<n { sum += channel[i] * channel[i] }
            rms = (sum / Float(n)).squareRoot()
        }
        onLevel?(rms)

        let elapsed = Date().timeIntervalSince(startedAt ?? Date())
        if watchdog.observe(rms: rms, at: elapsed) || elapsed > maxDuration {
            onAutoStop?()
        }

        // Convert to 16kHz mono Int16 on the tap thread (cheap, no file I/O).
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 16)
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat,
                                         frameCapacity: capacity) else { return }
        var consumed = false
        var conversionError: NSError?
        converter.convert(to: out, error: &conversionError) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard conversionError == nil,
              let channel = out.int16ChannelData?[0], out.frameLength > 0 else { return }
        let samples = Array(UnsafeBufferPointer(start: channel,
                                                count: Int(out.frameLength)))
        // Hand the converted samples to the serial queue; the WavWriter append
        // (the only file I/O) runs there, never on the real-time tap thread.
        writerQueue.async { [weak self] in
            try? self?.writer?.append(samples: samples)
        }
    }
}

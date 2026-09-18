import Foundation
import FluidAudio

/// Acoustic speech detection before Whisper sees audio. Energy alone cannot
/// distinguish microphone hiss/fans from a quiet voice. No word blacklist:
/// legitimate short responses such as "obrigado" must remain transcribable.
final class LocalSpeechGate: Sendable {
    private let vad: VadManager

    init() async throws {
        // Conservative admission: reject non-speech without requiring the
        // diarization-oriented default of 0.85 for quiet conversational speech.
        vad = try await VadManager(config: VadConfig(defaultThreshold: 0.5))
    }

    func containsSpeech(_ samples: [Float]) async throws -> Bool {
        guard !samples.isEmpty else { return false }
        // segmentSpeech starts with fresh recurrent state per buffer: previews
        // overlap, and mic/system buffers must not share voice history.
        let segments = try await vad.segmentSpeech(samples, config: VadSegmentationConfig(
            minSpeechDuration: 0.15, speechPadding: 0))
        return !segments.isEmpty
    }
}

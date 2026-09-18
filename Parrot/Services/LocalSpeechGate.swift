import Foundation
import FluidAudio

/// Acoustic speech detection before Whisper sees audio. Energy alone cannot
/// distinguish microphone hiss/fans from a quiet voice. No word blacklist:
/// legitimate short responses such as "obrigado" must remain transcribable.
final class LocalSpeechGate: Sendable {
    private let vad: VadManager

    init() async throws {
        // At 0.5, brief webcam noise peaks (0.53–0.58 in a real silent-mic
        // recording) admitted whole
        // chunks that Whisper confidently decoded as "Obrigado". Quiet speech
        // still needs headroom: the quiet short-greeting fixture peaks at 0.81,
        // so the model's default 0.85 would drop it. Keep both regressions.
        vad = try await VadManager(config: VadConfig(defaultThreshold: 0.75))
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

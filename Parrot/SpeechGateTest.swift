import Foundation
import AVFoundation

/// Real local VAD regression test. Uses synthetic non-speech and a supplied
/// 16 kHz mono speech fixture; never opens the microphone or system capture.
enum SpeechGateTest {
    static func run(path: String) {
        Task {
            do {
                let gate = try await LocalSpeechGate()
                let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
                guard file.processingFormat.sampleRate == 16000,
                      file.processingFormat.channelCount == 1,
                      file.length > 16000,
                      let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                   frameCapacity: AVAudioFrameCount(file.length)) else {
                    throw NSError(domain: "SpeechGateTest", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Expected a 16 kHz mono speech fixture longer than one second"])
                }
                try file.read(into: buffer)
                let speech = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
                var seed: UInt64 = 42
                let hiss: [Float] = (0..<192000).map { _ in
                    seed = seed &* 6364136223846793005 &+ 1
                    return (Float(seed >> 40) / Float(1 << 24) - 0.5) * 0.008
                }
                var click = [Float](repeating: 0, count: 32000)
                for i in 8000..<8080 { click[i] = i.isMultiple(of: 2) ? 0.3 : -0.3 }
                let cases: [(String, [Float], Bool)] = [
                    ("digital silence", [Float](repeating: 0, count: 192000), false),
                    ("steady microphone hiss", hiss, false),
                    ("DC offset", [Float](repeating: 0.002, count: 192000), false),
                    ("brief click", click, false),
                    ("spoken thank-you and greeting", speech, true),
                    ("quiet speech", speech.map { $0 * 0.08 }, true),
                    ("silence after speech, no recurrent-state leak", [Float](repeating: 0, count: 32000), false)
                ]
                for (name, samples, expected) in cases {
                    let start = Date()
                    let actual = try await gate.containsSpeech(samples)
                    guard actual == expected else {
                        print("FAIL \(name): speech=\(actual), expected=\(expected)")
                        exit(1)
                    }
                    print(String(format: "PASS %@ (%.3fs)", name, Date().timeIntervalSince(start)))
                }
                print("ALL SPEECH GATE CHECKS PASSED")
                exit(0)
            } catch {
                print("Speech gate test failed: \(error)")
                exit(1)
            }
        }
        RunLoop.main.run()
    }
}

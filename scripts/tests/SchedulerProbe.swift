import Foundation
enum AudioSource { case me, them; var label: String { self == .me ? "Me" : "Them" } }
struct ProfileKind { let key: String }
struct SentimentGauge { let key: String }
struct CallProfile { let id = UUID(); let tone = ""; let persona = ""; let counterpart = "prospect"; let allowGeneralKnowledge = false; let kinds = [ProfileKind(key: "question")]; let gauges: [SentimentGauge] = [] }
struct KBReference {}
struct Doc { let name: String }
class KnowledgeBaseService { let documents: [Doc] = []; func search(query: String, profileID: UUID?) async -> [KBReference] { [] }; func documentNames(for id: UUID) -> [String] { [] } }
struct Insight { let id = UUID(); let kindKey: String; let title: String; let detail: String; let callTime: TimeInterval; let source: String?; let reply: String?; var isHandled = false }
protocol AnalysisProvider { var isConfigured: Bool { get }; func analyze(_ request: AnalysisRequest) async throws -> AnalysisResult }
enum AnalysisError: Error { case missingAPIKey; case badResponse(String) }
class ClaudeAnalysisProvider: AnalysisProvider { var isConfigured: Bool { true }; var calls = 0; var fail = false; var failOnce = false; var delay: Double = 0; var requests: [AnalysisRequest] = []
func analyze(_ request: AnalysisRequest) async throws -> AnalysisResult { calls += 1; requests.append(request); if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }; if failOnce { failOnce = false; throw AnalysisError.badResponse("temporary") }; if fail { throw AnalysisError.badResponse("temporary") }; return AnalysisResult(insights: [], sentiment: [:], read: nil, coach: nil, resolved: []) }
}

@main struct Probe {
    @MainActor static func check(_ condition: Bool, _ message: String) {
        guard condition else { fatalError("FAIL: " + message) }
        print("PASS: " + message)
    }
    @MainActor static func main() async throws {
        UserDefaults.standard.setVolatileDomain(["copilotEnabled": true, "copilotPace": "fast"], forName: UserDefaults.argumentDomain)
        let mock = ClaudeAnalysisProvider()
        let engine = CallAnalysisEngine(provider: mock)
        engine.start(profile: CallProfile(), brief: "Confirmed context only")
        engine.ingest(text: "Quanto custa?", at: 1, source: .them)
        try await Task.sleep(for: .seconds(1.5))
        check(mock.calls == 1, "first question dispatched")
        check(mock.requests[0].callBrief == "Confirmed context only", "account brief reaches provider")
        engine.ingest(text: "Pode explicar?", at: 3, source: .them)
        try await Task.sleep(for: .seconds(1.5))
        engine.setPaused(true)
        try await Task.sleep(for: .seconds(4))
        check(mock.calls == 1 && engine.status == .paused, "pause cancels minimum-interval dispatch")
        engine.setPaused(false)
        try await Task.sleep(for: .seconds(0.5))
        check(mock.calls == 2, "resume retains pending speech")
        engine.stop()

        let slow = ClaudeAnalysisProvider(); slow.delay = 2
        let e2 = CallAnalysisEngine(provider: slow)
        e2.start(profile: CallProfile())
        e2.ingest(text: "Quem decide?", at: 1, source: .them)
        try await Task.sleep(for: .seconds(1.5))
        e2.setPaused(true)
        try await Task.sleep(for: .seconds(2.5))
        check(e2.status == .paused, "canceled in-flight result cannot overwrite pause")
        slow.delay = 0
        e2.setPaused(false)
        try await Task.sleep(for: .seconds(0.5))
        check(slow.calls == 2, "resume retries canceled in-flight transcript")
        e2.stop()

        let failing = ClaudeAnalysisProvider(); failing.failOnce = true
        let e3 = CallAnalysisEngine(provider: failing)
        e3.start(profile: CallProfile())
        e3.ingest(text: "What is the price?", at: 1, source: .them)
        try await Task.sleep(for: .seconds(7))
        check(failing.calls == 2 && e3.status == .listening, "transient failure retries without new speech")
        e3.stop()

        let alwaysFailing = ClaudeAnalysisProvider(); alwaysFailing.fail = true
        let e4 = CallAnalysisEngine(provider: alwaysFailing)
        e4.start(profile: CallProfile()); e4.ingest(text: "Quanto?", at: 1, source: .them)
        try await Task.sleep(for: .seconds(18))
        check(alwaysFailing.calls == 3, "automatic retries are bounded to two")
        e4.setPaused(true)
        try await Task.sleep(for: .seconds(1))
        check(alwaysFailing.calls == 3, "paused failed engine stays quiet")
        e4.stop()

        let echo = ClaudeAnalysisProvider(); let e5 = CallAnalysisEngine(provider: echo)
        e5.start(profile: CallProfile())
        let micID = UUID()
        e5.ingest(text: "A proposta custa dez mil", at: 1, source: .me, id: micID)
        e5.retractSegments(ids: [micID])
        e5.ingest(text: "A proposta custa dez mil?", at: 1, source: .them)
        try await Task.sleep(for: .seconds(1.5))
        check(echo.requests.count == 1 && !echo.requests[0].transcript.contains("Me:"), "retracted mic echo never reaches provider")
        e5.stop()
        check(CallAnalysisEngine.looksLikeQuestion("Quanto custa o projeto"), "Portuguese question without punctuation")
        check(CallAnalysisEngine.looksLikeQuestion("Qual é a metodologia"), "accented Portuguese question")
        check(!CallAnalysisEngine.looksLikeQuestion("Gostei porque economiza tempo"), "causal porque does not trigger question fast path")
        print("ALL SCHEDULER CHECKS PASSED")
    }
}

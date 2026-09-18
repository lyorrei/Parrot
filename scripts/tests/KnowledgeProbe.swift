import Foundation
extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
@main struct KnowledgeProbe {
    @MainActor static func main() async throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        try "The account has a confirmed marketing measurement project. Pricing must be verified with the commercial team.".write(to: url, atomically: true, encoding: .utf8)
        // Deterministic embedding tests storage/scoping, not model quality.
        let kb = KnowledgeBaseService(persistent: false, embedding: { _, _ in [1, 0] })
        await kb.addDocuments(at: [url])
        guard let doc = kb.documents.first else { fatalError("import failed") }
        let profileID = UUID()
        kb.setProfiles([profileID], for: doc)
        kb.updateNote("Confirmed account context", for: doc)
        await kb.addDocuments(at: [url])
        guard let updated = kb.documents.first,
              updated.id == doc.id, updated.profileIDs == [profileID],
              updated.note == "Confirmed account context", kb.documents.count == 1 else {
            fatalError("FAIL reimport identity, profile or note")
        }
        let found = await kb.search(query: "pricing", profileID: profileID)
        let otherAccount = await kb.search(query: "pricing", profileID: UUID())
        guard found.count == 1, otherAccount.isEmpty else { fatalError("FAIL profile scoping") }
        let lexical = KnowledgeBaseService(persistent: false, embedding: { _, _ in nil })
        try "A análise de YouTube precisa confirmar o investimento e a metodologia antes de prometer resultados ao cliente.".write(to: url, atomically: true, encoding: .utf8)
        await lexical.addDocuments(at: [url])
        guard let lexicalDoc = lexical.documents.first else { fatalError("FAIL import without embeddings") }
        lexical.setProfiles([profileID], for: lexicalDoc)
        let matched = await lexical.search(query: "analise YouTube", profileID: profileID)
        let unrelated = await lexical.search(query: "hipoteca", profileID: profileID)
        guard matched.count == 1, unrelated.isEmpty else { fatalError("FAIL lexical fallback") }
        print("PASS: Portuguese retrieval without Apple embedding assets")
        print("PASS: reimport preserves identity, note, profile and scoped retrieval")
    }
}

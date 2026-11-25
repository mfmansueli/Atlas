//
//  TranslationFieldsMCPTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Board 77's MCP fields: means, sounds, notes, natural, naturalMeans and
/// drift, read and checked like every card text.
@Suite("Translation fields over MCP")
struct TranslationFieldsMCPTests {
    private func layers(_ values: [String: JSONValue]) throws -> SuggestionLayers? {
        try MCPToolArguments(values).layers()
    }

    @Test func meansIsTheGloss() throws {
        #expect(try layers(["means": "Your week on one calm page"])?.means == "Your week on one calm page")
        #expect(try layers(["gloss": "Older calls"])?.means == "Older calls")
        #expect(try layers(["means": "New", "gloss": "Old"])?.means == "New")
    }

    @Test func soundsTakesItsThreeNames() throws {
        #expect(try layers(["sounds": "native"])?.translation?.sounds == .native)
        #expect(try layers(["sounds": "translated"])?.translation?.sounds == .translated)
        #expect(try layers(["sounds": "off"])?.translation?.sounds == .off)
        // 1–3, as the board first drew it, read the same way.
        #expect(try layers(["sounds": 3])?.translation?.sounds == .native)
        #expect(try layers(["sounds": 1])?.translation?.sounds == .off)
    }

    @Test func anUnknownSoundsIsRefused() {
        #expect(throws: MCPToolError.self) { try layers(["sounds": "great"]) }
        #expect(throws: MCPToolError.self) { try layers(["sounds": 4]) }
    }

    @Test func notesNeedAPhraseAndWhatToWriteInstead() throws {
        let read = try layers(["sounds": "translated", "notes": [["phrase": "Jahre an Einträgen", "natural": "Einträge aus Jahren", "why": "Word order."]]])
        #expect(read?.translation?.notes == [TranslationNote(phrase: "Jahre an Einträgen", natural: "Einträge aus Jahren", why: "Word order.")])
        #expect(throws: MCPToolError.self) { try layers(["notes": [["phrase": "", "natural": "x", "why": "y"]]]) }
        #expect(throws: MCPToolError.self) { try layers(["notes": [["phrase": "x", "why": "y"]]]) }
    }

    @Test func aNoteOverItsLimitIsRefused() {
        let why = String(repeating: "a", count: AssistantTextLimits.why + 1)
        #expect(throws: MCPToolError.self) { try layers(["notes": [["phrase": "x", "natural": "y", "why": .string(why)]]]) }
    }

    @Test func naturalMeansNeedsNatural() {
        #expect(throws: MCPToolError.self) { try layers(["naturalMeans": "Mood journal and prompts"]) }
    }

    @Test func withoutTheFieldsThereIsNoReading() throws {
        #expect(try layers(["means": "Only what it says"])?.translation == nil)
        #expect(try layers([:]) == nil)
    }

    @Test func meansOverTwoHundredTwentyIsRefusedBeforeTheCall() {
        let schema: JSONValue = MCPToolDefinition.schema(MCPToolDefinition.withLayers([:], gloss: true))
        let long = String(repeating: "a", count: AssistantTextLimits.means + 1)
        #expect(AssistantTextCheck.refusal(["means": .string(long)], schema: schema) != nil)
        #expect(AssistantTextCheck.refusal(["means": .string(String(repeating: "a", count: 200))], schema: schema) == nil)
        #expect(AssistantTextCheck.refusal(["naturalMeans": .string(long)], schema: schema) != nil)
    }

    @MainActor
    @Test func toolsThatCarryLocalizedTextsListTheFields() {
        let suggest = SuggestFieldsTool().definition.inputSchema.jsonString()
        for name in ["means", "sounds", "notes", "natural", "naturalMeans", "drift"] {
            #expect(suggest.contains("\"\(name)\""))
        }
        let events = ProposeEventTextsTool().definition.inputSchema
        let eventItem = events["properties"]?["texts"]?["items"]?["properties"]
        #expect(eventItem?["sounds"] != nil)
        #expect(eventItem?["natural"] == nil)
        let captions = ProposeCaptionsTool().definition.inputSchema["properties"]?["items"]?["items"]?["properties"]
        #expect(captions?["natural"] != nil)
    }

    @Test func aNaturalVersionFollowsTheFieldsRules() throws {
        func refusal(_ natural: String, field: ListingField) throws -> String? {
            try MCPNaturalCheck.refusal(layers(["sounds": "off", "natural": .string(natural)]), for: field)
        }
        #expect(try refusal("Dziennik nastroju i podpowiedzi", field: .subtitle) == nil)
        #expect(try refusal(String(repeating: "a", count: 31), field: .subtitle)?.hasPrefix("natural:") == true)
        #expect(try refusal("Dziennik nastroju — free", field: .subtitle) != nil)
    }

    @Test func getToolsListTheReadingBack() throws {
        let read = try #require(try layers([
            "means": "Mood journal and inspirations", "sounds": "off", "natural": "Dziennik nastroju i podpowiedzi",
            "naturalMeans": "Mood journal and prompts", "drift": [["phrase": "inspirations", "original": "prompts"]],
        ]))
        let fields = read.mcpFields
        #expect(fields["means"] == "Mood journal and inspirations")
        #expect(fields["sounds"] == "off")
        #expect(fields["natural"] == "Dziennik nastroju i podpowiedzi")
        #expect(fields["drift"] != nil)
        #expect(fields["usesNatural"] == nil)
    }
}

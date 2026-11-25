//
//  EndSuggestionsTool.swift
//  Atlas
//

import Foundation

/// `end_suggestions`: the assistant sent everything it will for a Suggest
/// Everything run. What arrived stays for the person to review; planned
/// fields that never came stop showing as coming.
struct EndSuggestionsTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "end_suggestions",
        title: "End suggesting everything",
        description: """
        Ends a Suggest Everything run once you've sent every suggestion you will. What arrived stays in \
        Atlas for the person to review. Returns the run's status (finished, or stopped when the person \
        stopped receiving) and how many of its fields arrived. With locale, it ends one language of a \
        begin_translation run, once its writer and reviewer are done: Atlas counts it ("4 of 12 languages"), \
        its fields that never came stop showing as coming, and the run finishes with the last language \
        (status languageEnded, or finished).
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "run": MCPToolDefinition.string("The run begin_suggestions or begin_translation returned."),
                "locale": MCPToolDefinition.string("For a begin_translation run: the language that's done, e.g. de-DE."),
            ],
            required: ["run"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        guard let store = context.workspace.suggestions else {
            throw MCPToolError.unavailable(String(localized: "Suggestions aren’t available right now. Ask the person to open Atlas."))
        }
        let id = try arguments.string("run")
        if store.isStopped(id) {
            return .read(["run": .string(id), "status": "stopped"], target: id)
        }
        guard let run = store.run, run.id == id, run.phase != .waiting else {
            throw MCPToolError.notFound(String(localized: "There’s no run “\(id)” going on. Start one with begin_suggestions."))
        }
        if let code = try arguments.optionalString("locale") {
            return try Self.endLanguage(code, of: run, in: store)
        }
        store.endRun(id: id)
        let result: JSONValue = [
            "run": .string(id),
            "status": "finished",
            "received": .int(run.received),
            "total": .int(run.total),
        ]
        return .read(result, target: id)
    }

    /// One language of a translation run is done.
    private static func endLanguage(_ code: String, of run: SuggestionRun, in store: FieldSuggestionStore) throws -> MCPToolOutcome {
        if run.isOver, run.languages.contains(code) {
            return .read(["run": .string(run.id), "locale": .string(code), "status": "finished"], target: "\(run.id) · \(code)")
        }
        guard let ended = store.endLanguage(code, inRun: run.id) else {
            let languages = run.languages.isEmpty ? String(localized: "none: end it without a locale") : run.languages.joined(separator: ", ")
            throw MCPToolError.notFound(String(localized: "Run “\(run.id)” has no language “\(code)”. Its languages: \(languages).", comment: "kind:error"))
        }
        let result: JSONValue = [
            "run": .string(ended.id),
            "locale": .string(code),
            "status": ended.phase == .finished ? "finished" : "languageEnded",
            "languagesDone": .int(ended.languagesDone),
            "languages": .int(ended.languages.count),
            "received": .int(ended.received),
        ]
        return .read(result, target: "\(ended.id) · \(code)")
    }
}

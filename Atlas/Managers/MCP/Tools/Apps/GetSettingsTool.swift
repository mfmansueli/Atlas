//
//  GetSettingsTool.swift
//  Atlas
//

import Foundation

/// `get_settings`: the Atlas settings that shape what an assistant
/// suggests, read-only: what the person lets assistants suggest (Settings →
/// AI Assistants), whether suggestions may be written as drafts, Pro,
/// Settings → Translation's source language, glossary and tone, and
/// Settings → Pricing's commission. The person changes them in Atlas.
struct GetSettingsTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "get_settings",
        title: "Get Atlas settings",
        description: """
        Reads the Atlas settings that shape your suggestions: assistantMay (what the person lets assistants suggest, \
        from Settings → AI Assistants: storeText, screenshots, prices, appInformation, reviewReplies, artwork, \
        release; a proposal of a kind that's off is refused), editsDrafts (suggest_fields may write values as \
        unpushed changes), pro (whether the account has Atlas Pro; some features, like suggested replies, need it), \
        translation (sourceLocale: the language translations start from, or each app's primary locale when null; \
        glossary terms to keep and the tone) and commission (the share Apple keeps, for proceeds). Read-only: only \
        the person changes them, in Atlas → Settings.
        """,
        inputSchema: MCPToolDefinition.schema()
    )

    func call(_: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let workspace = context.workspace
        let glossary = workspace.glossary()
        let allowed = MCPProposalKind.allCases.filter(context.allows)
        let result: JSONValue = [
            "assistantMay": .array(allowed.map { .string($0.rawValue) }),
            "assistantMayNot": .array(MCPProposalKind.allCases.filter { !context.allows($0) }.map { .string($0.rawValue) }),
            "editsDrafts": .bool(context.editsDrafts),
            "pro": workspace.isPro().map(JSONValue.bool) ?? .null,
            "translation": [
                "sourceLocale": workspace.translationSource().map(JSONValue.string) ?? .null,
                "keepUntranslated": .array(glossary.terms.map(JSONValue.string)),
                "tone": .string(glossary.tone.rawValue),
            ],
            "commission": .double(workspace.commission().rate.doubleValue),
            "client": .string(context.clientName),
        ]
        return .read(result, target: String(localized: "\(workspace.teamName) · Settings", comment: "kind:other"))
    }
}

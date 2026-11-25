//
//  ProposeAppPreviewOrderTool.swift
//  Atlas
//

import Foundation

/// `propose_app_preview_order`: deletes App Previews from one language's
/// set on iPhone or iPad, or puts them in a new order, as the Screenshots
/// language page's Delete and arrows do (`AppPreviewSetPush.Content`).
/// It's queued as the language's App Previews by hand and goes only when
/// the person pushes.
struct ProposeAppPreviewOrderTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "propose_app_preview_order",
        title: "Propose App Previews to delete or reorder",
        description: """
        Changes one language's App Previews on iphone or ipad as the person does on its Screenshots page: delete \
        lists the positions to take out (from 1, as get_screenshot_context's appPreviews lists them), order the \
        positions in their new order (every position kept, once). Send one or both; deleting comes first, and order \
        then names the positions as they were before. Proposing again for the same language and device changes the \
        waiting set. It waits in Review & Push (status "queued"); nothing reaches the App Store until the person pushes.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "locale": MCPToolDefinition.string("The language, e.g. de-DE."),
                "displayType": MCPToolDefinition.string("iphone or ipad."),
                "delete": ["type": "array", "items": ["type": "integer", "minimum": 1, "maximum": 3], "description": "Positions to delete, from 1."],
                "order": ["type": "array", "items": ["type": "integer", "minimum": 1, "maximum": 3], "description": "The kept positions in their new order."],
                "reason": MCPToolDefinition.why("Why, for the person to read in Review & Push."),
            ]),
            required: ["appId", "locale", "displayType", "reason"]
        ),
        proposalKind: .screenshots
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let workspace = context.workspace
        let app = try await workspace.app(matching: arguments.string("appId"))
        let code = try arguments.string("locale").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let locale = StoreLocaleCatalog.locale(code: code) else {
            throw MCPToolError.invalidArgument(name: "locale", expected: "a store locale such as de-DE")
        }
        guard let display = try ScreenshotDisplayType(mcpValue: arguments.string("displayType")), AppPreviewSpec.displayTypes.contains(display) else {
            throw MCPToolError.invalidArgument(name: "displayType", expected: "iphone or ipad")
        }
        let deletions = try (arguments.optionalArray("delete") ?? []).map { try Self.position($0, name: "delete") }
        let order = try arguments.optionalArray("order").map { try $0.map { try Self.position($0, name: "order") } }
        guard !deletions.isEmpty || order != nil else {
            throw MCPToolError.invalidArgument(name: "delete", expected: String(localized: "positions to delete, or order"))
        }
        let reason = try arguments.string("reason")
        let target = "\(app.name) · \(locale.code) · \(display.shortTitle) · App Previews"
        guard context.allows(.screenshots) else { return .refused(MCPProposalKind.screenshots.refusal, target: target) }
        let (screenshotsContext, live) = try await ProposeAppPreviewFileTool.read(app, in: workspace)
        guard let localizationID = screenshotsContext.localizations.first(where: { $0.key.code == locale.code })?.value else {
            return .refused(String(localized: "\(app.name)’s version has no \(locale.name). Add the language first."), target: target)
        }
        let liveSet = live.previewSets.first { $0.locale == locale.code && $0.displayType == display }
        let queued = AppPreviewHandChange.queued(in: workspace.changes, appID: app.id, locale: locale.code, displayType: display)
        let start = queued.flatMap(AppPreviewHandChange.content)
            ?? .start(appID: app.id, localizationID: localizationID, locale: locale.code, displayType: display, live: liveSet)
        let content: AppPreviewSetPush.Content
        switch Self.edit(start, deleting: deletions, order: order) {
        case let .success(edited): content = edited
        case let .failure(problem): return .refused(problem.text, target: target)
        }
        let id = AppPreviewHandChange.id(appID: app.id, locale: locale.code, displayType: display)
        if content.isUnchanged(from: liveSet) {
            if workspace.changes.change(id: id)?.source == context.source { workspace.changes.discard(id: id) }
            let note = String(localized: "That’s the set live on the App Store; nothing waits for it now.")
            return MCPToolOutcome(result: ["status": "unchanged", "note": .string(note)], isError: false, logLines: [.init(target: target, outcome: .read)])
        }
        let liveCount = liveSet?.previews?.count ?? liveSet?.previewCount ?? 0
        let change = AppPreviewHandChange.change(content, localeName: locale.name, liveCount: liveCount, source: context.source, reason: reason)
        let layers = try arguments.layers()
        workspace.changes.upsert(change)
        workspace.changes.attach(layers?.nonEmpty, to: change.id)
        let result: [String: JSONValue] = [
            "status": "queued",
            "changeId": .string(change.id),
            "appPreviews": .array(content.slots.enumerated().map { ["position": .int($0.offset + 1), "fileName": .string($0.element.fileName)] }),
            "deletedOnPush": .int(content.deletedIDs.count),
            "showsIn": .string("Review & Push, and Screenshots → \(locale.name) → \(display.title) → App Previews"),
        ]
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    struct Problem: Error, Equatable {
        var text: String
    }

    /// The set after deleting `deletions` and putting what's left in
    /// `order` (positions as they were before deleting), from 1.
    static func edit(
        _ content: AppPreviewSetPush.Content, deleting deletions: [Int], order: [Int]?
    ) -> Result<AppPreviewSetPush.Content, Problem> {
        let count = content.slots.count
        if let wrong = (deletions + (order ?? [])).first(where: { $0 < 1 || $0 > count }) {
            return .failure(Problem(text: String(localized: "There’s no App Preview \(wrong): the set has \(count). Read get_screenshot_context first.")))
        }
        let kept = (1...max(count, 1)).filter { $0 <= count && !deletions.contains($0) }
        if let order, order.sorted() != kept {
            let list = kept.map(String.init).formatted(.list(type: .and))
            return .failure(Problem(text: String(localized: "order names every App Preview kept, once: \(list).")))
        }
        var edited = content
        for position in Set(deletions).sorted(by: >) {
            edited.delete(at: position - 1)
        }
        if let order {
            let slots = order.compactMap { position in kept.firstIndex(of: position).map { edited.slots[$0] } }
            edited.slots = slots
        }
        return .success(edited)
    }

    private static func position(_ value: JSONValue, name: String) throws -> Int {
        guard let number = value.intValue else { throw MCPToolError.invalidArgument(name: name, expected: String(localized: "positions from 1")) }
        return number
    }
}

//
//  ProposeScreenshotOrderTool.swift
//  Atlas
//

import Foundation

/// `propose_screenshot_order`: suggests a new order for a language's set
/// on one device, naming every screenshot once. It waits on the
/// Screenshots language page; accepting moves them as ◀ ▶ do, and pushing
/// reorders the set in App Store Connect without uploading anything again.
struct ProposeScreenshotOrderTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "propose_screenshot_order",
        title: "Propose a screenshot order",
        description: """
        Suggests a new order for one language's set on one device: `order` lists every screenshot's current position (from \
        1) in the new order, e.g. [3, 1, 2, 4, 5] puts the third first; or pass `screenshotIds` in the new order, as \
        get_screenshot_context lists them with the same locale and displayType. Name each screenshot once, all of them: to \
        drop some, use propose_screenshot_removal. It waits on the Screenshots language page for the person to accept or \
        dismiss; pushing then reorders the set in App Store Connect, uploading nothing again. Screenshots Atlas makes from \
        the template move only in this language's set: they're still redrawn when the template or the caption changes, and \
        the other languages keep the template's order. Sending another order for the same set replaces the waiting one.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPHandArrangementQueue.commonProperties.merging([
                "order": ["type": "array", "items": ["type": "integer"], "description": "Every screenshot's current position, from 1, in the new order."],
                "screenshotIds": ["type": "array", "items": ["type": "string"], "description": "Or every screenshot's id, in the new order."],
            ]) { old, _ in old },
            required: ["appId", "locale", "displayType", "reason"]
        ),
        proposalKind: .screenshots
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let order = try MCPHandArrangementQueue.positions("order", in: arguments) ?? []
        let ids = try arguments.optionalStrings("screenshotIds") ?? []
        guard order.isEmpty != ids.isEmpty else {
            throw MCPToolError.invalidArgument(
                name: "order",
                expected: String(localized: "either order (positions from 1) or screenshotIds, listing every screenshot")
            )
        }
        return try await MCPHandArrangementQueue.queue(.order, arguments, in: context) { set in
            let named = set.places(positions: order, ids: ids)
            guard case let .success(places) = named, places.count != set.places.count else { return named }
            let listed = Set(places.map(\.mcpID))
            let missing = set.places.filter { !listed.contains($0.mcpID) }.map { String($0.position + 1) }
            return .failure(MCPScreenshotHandSet.Refusal(String(localized: """
            Name every screenshot once: \(set.locale.name) has \(set.places.count) on \(set.displayType.title), and the order leaves out \
            \(missing.formatted(.list(type: .and))). To drop some, use propose_screenshot_removal.
            """)))
        }
    }
}

//
//  ProposeScreenshotRemovalTool.swift
//  Atlas
//

import Foundation

/// `propose_screenshot_removal`: suggests deleting screenshots from a
/// language's set on one device, by position or ID. It waits on the
/// Screenshots language page; accepting marks them "Will be deleted", as
/// Delete… does, and pushing deletes them after any uploads.
struct ProposeScreenshotRemovalTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "propose_screenshot_removal",
        title: "Propose deleting screenshots",
        description: """
        Suggests deleting screenshots from one language's set on one device. Name them by position (from 1) or by id, as \
        get_screenshot_context lists them when you pass it the same locale and displayType. It waits on the Screenshots \
        language page for the person to accept or dismiss; accepting marks them “Will be deleted” and the ones after them \
        move up, then pushing deletes them in App Store Connect (after any uploads, so a failed upload never leaves the \
        language with fewer). A screenshot Atlas makes from the template goes only from this language's set: the template \
        keeps the slot, and the other languages keep their screenshot there. The primary language must keep at least one \
        screenshot per device. A language with no screenshots of its own shows the primary one's: there's nothing to \
        delete. Sending another removal for the same set replaces the waiting one.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPHandArrangementQueue.commonProperties.merging([
                "positions": ["type": "array", "items": ["type": "integer"], "description": "The screenshots to delete, from 1."],
                "screenshotIds": ["type": "array", "items": ["type": "string"], "description": "Or their ids from get_screenshot_context."],
            ]) { old, _ in old },
            required: ["appId", "locale", "displayType", "reason"]
        ),
        proposalKind: .screenshots
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let positions = try MCPHandArrangementQueue.positions("positions", in: arguments) ?? []
        let ids = try arguments.optionalStrings("screenshotIds") ?? []
        guard !positions.isEmpty || !ids.isEmpty else {
            throw MCPToolError.invalidArgument(name: "positions", expected: String(localized: "the positions or screenshotIds of the screenshots to delete"))
        }
        return try await MCPHandArrangementQueue.queue(.removal, arguments, in: context) { set in
            set.places(positions: positions, ids: ids)
        }
    }
}

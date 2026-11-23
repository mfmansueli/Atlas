//
//  MarkCapturesStaleTool.swift
//  Atlas
//

import Foundation

/// `mark_captures_stale`: the assistant says some captures no longer show
/// the app as it is (its Japanese phrases were rewritten). Screenshots →
/// Captures labels them "Out of date" and list_captures says so, until a
/// new capture takes their place. Nothing else changes.
struct MarkCapturesStaleTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "mark_captures_stale",
        title: "Mark captures out of date",
        description: """
        Marks captures (real screenshots of the app, as list_captures has them) out of date because the app changed \
        under them, with the reason and evidence (a file or commit) the person reads. Each item of targets is a slot \
        (from 1) or a screen's name, a locale, and a displayType (left out: every device). Screenshots → Captures \
        labels them Out of date and list_captures returns stale with the reason, until a new capture takes their \
        place. To have them captured again, ask with request_recapture.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "targets": [
                    "type": "array",
                    "description": "The captures out of date.",
                    "items": MCPToolDefinition.schema(
                        [
                            "slot": ["type": "integer", "description": "The slot, from 1, as list_captures has it."],
                            "screen": MCPToolDefinition.string("Instead of slot: the slot's name, e.g. Today."),
                            "locale": MCPToolDefinition.string("The locale, e.g. ja."),
                            "displayType": MCPToolDefinition.string("iphone, iphone_duo, ipad or mac; leave out for every device."),
                        ],
                        required: ["locale"]
                    ),
                ],
                "reason": MCPToolDefinition.shortWhy("What changed, in a sentence the person reads."),
                "evidence": MCPToolDefinition.string("What shows it: a file or commit."),
            ],
            required: ["appId", "targets", "reason"]
        ),
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        var draft = try await MCPScreenshotsDraft.load(app: arguments.string("appId"), in: context.workspace)
        let staleness = try CaptureStaleness(
            reason: arguments.string("reason"), evidence: arguments.optionalString("evidence"), client: context.clientName, markedAt: .now
        )
        var marked = 0
        var refused: [JSONValue] = []
        for item in try arguments.array("targets") {
            switch cells(item, in: draft) {
            case let .success(cells):
                var count = 0
                for cell in cells where draft.document.captures.markStale(locale: cell.locale, displayType: cell.display, slot: cell.slot, as: staleness) {
                    count += 1
                }
                if count == 0 {
                    refused.append(Self.refusal(item, reason: String(localized: "That locale has no capture of its own there.")))
                }
                marked += count
            case let .failure(reason):
                refused.append(Self.refusal(item, reason: reason.message))
            }
        }
        var result: [String: JSONValue] = ["marked": .int(marked)]
        if !refused.isEmpty { result["refused"] = .array(refused) }
        guard marked > 0 else { return .refused(String(localized: "No capture was marked."), target: draft.target, details: result) }
        try await draft.save()
        result["status"] = refused.isEmpty ? "marked" : "partial"
        result["say"] = .string(String(localized: """
        Screenshots → Captures labels them Out of date. To have them captured again, ask with request_recapture.
        """))
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: draft.target, outcome: .proposed)])
    }

    private struct Refusal: Error {
        var message: String
    }

    /// The cells an item names: a slot or a slot's name, in a locale, on
    /// one device or every one.
    private func cells(_ item: JSONValue, in draft: MCPScreenshotsDraft) -> Result<[(locale: String, display: ScreenshotDisplayType, slot: Int)], Refusal> {
        guard let code = item["locale"]?.stringValue, let locale = StoreLocaleCatalog.resolve(code).locale else {
            return .failure(Refusal(message: String(localized: "Send an App Store locale such as ja or de-DE.")))
        }
        let document = draft.document
        var displays = document.renderedDisplays
        if let value = item["displayType"]?.stringValue {
            guard let display = ScreenshotDisplayType(mcpValue: value) else {
                return .failure(Refusal(message: String(localized: "Send iphone, iphone_duo, ipad or mac.")))
            }
            displays = [display]
        }
        let slot: Int
        if let number = item["slot"]?.intValue {
            guard (1...max(document.slotCount, 1)).contains(number) else {
                return .failure(Refusal(message: String(localized: "Send a slot from 1 to \(document.slotCount).")))
            }
            slot = number - 1
        } else if let name = item["screen"]?.stringValue,
                  let index = (0..<document.slotCount).first(where: { document.slotName($0).localizedCaseInsensitiveCompare(name) == .orderedSame })
        {
            slot = index
        } else {
            let names = (0..<document.slotCount).map(document.slotName).joined(separator: ", ")
            return .failure(Refusal(message: String(localized: "Send a slot number, or one of the slots’ names: \(names).")))
        }
        return .success(displays.map { (locale.code, $0, slot) })
    }

    private static func refusal(_ item: JSONValue, reason: String) -> JSONValue {
        var json: [String: JSONValue] = ["reason": .string(reason)]
        for key in ["slot", "screen", "locale", "displayType"] {
            if let value = item[key], !value.isNull { json[key] = value }
        }
        return .object(json)
    }
}

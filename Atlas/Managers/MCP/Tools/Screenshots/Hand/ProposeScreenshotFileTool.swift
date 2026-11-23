//
//  ProposeScreenshotFileTool.swift
//  Atlas
//

import Foundation

/// `propose_screenshot_file`: suggests a file for one place of a
/// language's set on a device, replacing the screenshot there or added
/// after the last one. The file comes from the upload link in
/// `get_screenshot_context` and is checked like one the person adds: one of
/// the device's sizes, upright or turned, PNG or JPEG without
/// transparency, never scaled. It waits on the Screenshots language page
/// to be accepted or dismissed. Deleting and moving screenshots are
/// `propose_screenshot_removal`'s and `propose_screenshot_order`'s.
struct ProposeScreenshotFileTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "propose_screenshot_file",
        title: "Propose a screenshot file",
        description: """
        Suggests a screenshot file for one language and device: it replaces the screenshot at position (from 1) or, \
        without position, goes after the last one (at most 10 per set). Send the PNG or JPEG first with curl -s \
        --data-binary @01.png -H 'Content-Type: image/png' '<get_screenshot_context's fileUploadURL>?name=01.png' and \
        pass the fileId it returns. The file must be one of the device's App Store sizes (get_screenshot_context's \
        displayTypes list them), upright or turned, without transparency: Atlas never scales a screenshot, and a wrong \
        size is refused with the sizes to use. A file replacing a screenshot Atlas made from the template stops it \
        being redrawn when the template or caption changes. It waits on the Screenshots language page for the person \
        to accept or dismiss, then in Review & Push. Proposing the same place again replaces the waiting one. Positions \
        are as get_screenshot_context lists the set with the same locale and displayType. To delete screenshots use \
        propose_screenshot_removal, and to change their order propose_screenshot_order.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "locale": MCPToolDefinition.string("The language, e.g. de-DE."),
                "displayType": MCPToolDefinition.string("iphone, iphone_duo, ipad, mac, watch or vision_pro."),
                "position": ["type": "integer", "description": "The screenshot it replaces, from 1. Leave it out to add it after the last one."],
                "fileId": MCPToolDefinition.string("The fileId the upload link returned."),
                "reason": MCPToolDefinition.shortWhy("Why, for the person to read before accepting."),
            ],
            required: ["appId", "locale", "displayType", "fileId", "reason"]
        ),
        proposalKind: .screenshots
    )

    var uploads: ScreenshotHandUploads = .shared

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        var draft = try await MCPScreenshotsDraft.load(app: arguments.string("appId"), in: context.workspace)
        let locale = try draft.locale(arguments.string("locale"))
        let displayValue = try arguments.string("displayType")
        let display = try MCPScreenshotHandSet.displayType(displayValue)
        let position = try arguments.optionalInt("position")
        let target = "\(draft.app.name) · \(locale.code) · \(display.shortTitle)" + (position.map { " · \($0)" } ?? "")
        if let position, !(1...ScreenshotHandSet.capacity).contains(position) {
            return .refused(String(localized: "position is from 1 to \(ScreenshotHandSet.capacity), or left out to add it at the end."), target: target)
        }
        let fileID = try arguments.string("fileId").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let upload = uploads.upload(id: fileID, appID: draft.app.id) else {
            return .refused(String(localized: """
            No upload “\(fileID)” for \(draft.app.name) in this launch. Send the file to get_screenshot_context’s fileUploadURL \
            first and pass the fileId it returns.
            """), target: target)
        }
        if let problem = Self.problem(upload, on: display) {
            return .refused(problem, target: target)
        }
        var file = upload.file
        file.proposedBy = context.clientName
        let proposal = try ScreenshotHandProposal(
            id: ProposeTemplateTool.newID(), client: context.clientName, receivedAt: .now, locale: locale.code, displayType: display,
            position: position.map { $0 - 1 }, file: file, reason: arguments.string("reason")
        )
        var proposals = (draft.document.handProposals ?? []).filter { old in
            !(old.isWaiting && old.locale == proposal.locale && old.displayType == display && old.position == proposal.position)
        }
        proposals.append(proposal)
        draft.document.handProposals = proposals
        try await draft.save()
        uploads.remove(id: fileID)
        let result: [String: JSONValue] = [
            "status": "queued",
            "proposalId": .string(proposal.id),
            "showsIn": .string("Screenshots → \(locale.name) → \(display.title), to accept or dismiss, then Review & Push"),
            "next": "The person accepts or dismisses it; pushing uploads it. Never push it yourself.",
        ]
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// Why the file can't go into the device's set; nil when it fits.
    static func problem(_ upload: ScreenshotHandUploads.Upload, on display: ScreenshotDisplayType) -> String? {
        let size = upload.file.pixelSize
        guard ScreenshotHandSizes.accepts(size, on: display) else {
            return String(localized: """
            \(size.title) isn’t an \(display.title) size. Use \(ScreenshotHandSizes.all(on: display)), upright or turned. Atlas \
            never scales a screenshot: App Review rejects stretched ones.
            """)
        }
        if upload.hasTransparency {
            return String(localized: "The file has transparency, which App Store Connect refuses. Save it without an alpha channel and send it again.")
        }
        return nil
    }
}

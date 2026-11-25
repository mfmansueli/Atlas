//
//  ProposeAppPreviewFileTool.swift
//  Atlas
//

import Foundation

/// `propose_app_preview_file`: suggests a video for one place of a
/// language's App Previews on iPhone or iPad, replacing the one there or
/// added after the last one (up to 3). The video comes from the upload link
/// in `get_screenshot_context` and is checked like one the person
/// chooses: MOV, MP4 or M4V, the device's exact size upright or turned, 15
/// to 30 seconds, at most 500 MB. It's queued in Review & Push as the
/// language's App Previews by hand (`AppPreviewHandChange`), shown on the
/// Screenshots language page, and goes only when the person pushes.
struct ProposeAppPreviewFileTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "propose_app_preview_file",
        title: "Propose an App Preview file",
        description: """
        Suggests an App Preview video for one language on iphone or ipad: it replaces the App Preview at position \
        (from 1) or, without position, goes after the last one (at most 3 per set). Send the video first with curl -s \
        --data-binary @preview.mov -H 'Content-Type: video/quicktime' '<get_screenshot_context's appPreviewUploadURL>?name=preview.mov' \
        and pass the fileId it returns. App Store Connect takes MOV, MP4 or M4V, 15 to 30 seconds, at most 500 MB, at \
        exactly 886 × 1920 on iphone or 1200 × 1600 on ipad, upright or turned; anything else is refused with the fix. \
        It waits in Review & Push and on the Screenshots language page; nothing reaches the App Store until the person \
        pushes. Proposing the same language and device again changes the waiting set.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "locale": MCPToolDefinition.string("The language, e.g. de-DE."),
                "displayType": MCPToolDefinition.string("iphone or ipad."),
                "position": ["type": "integer", "description": "The App Preview it replaces, from 1. Leave it out to add it after the last one."],
                "fileId": MCPToolDefinition.string("The fileId the upload link returned."),
                "reason": MCPToolDefinition.why("Why, for the person to read in Review & Push."),
            ]),
            required: ["appId", "locale", "displayType", "fileId", "reason"]
        ),
        proposalKind: .screenshots
    )

    var uploads: AppPreviewUploads = .shared

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let workspace = context.workspace
        let app = try await workspace.app(matching: arguments.string("appId"))
        let code = try arguments.string("locale").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let locale = StoreLocaleCatalog.locale(code: code) else {
            throw MCPToolError.invalidArgument(name: "locale", expected: "a store locale such as de-DE")
        }
        let displayValue = try arguments.string("displayType")
        guard let display = ScreenshotDisplayType(mcpValue: displayValue), AppPreviewSpec.displayTypes.contains(display) else {
            throw MCPToolError.invalidArgument(name: "displayType", expected: "iphone or ipad")
        }
        let position = try arguments.optionalInt("position")
        let layers = try arguments.layers()
        let target = "\(app.name) · \(locale.code) · \(display.shortTitle) · App Preview" + (position.map { " \($0)" } ?? "")
        let fileID = try arguments.string("fileId").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let upload = uploads.upload(id: fileID, appID: app.id) else {
            return .refused(String(localized: """
            No upload “\(fileID)” for \(app.name) in this launch. Send the video to get_screenshot_context’s appPreviewUploadURL \
            first and pass the fileId it returns.
            """), target: target)
        }
        let (screenshotsContext, live) = try await Self.read(app, in: workspace)
        guard let localizationID = screenshotsContext.localizations.first(where: { $0.key.code == locale.code })?.value else {
            return .refused(String(localized: "\(app.name)’s version has no \(locale.name). Add the language first."), target: target)
        }
        let liveSet = live.previewSets.first { $0.locale == locale.code && $0.displayType == display }
        let queued = AppPreviewHandChange.queued(in: workspace.changes, appID: app.id, locale: locale.code, displayType: display)
        var content = queued.flatMap(AppPreviewHandChange.content)
            ?? .start(appID: app.id, localizationID: localizationID, locale: locale.code, displayType: display, live: liveSet)
        if let position, !content.slots.indices.contains(position - 1) {
            return .refused(String(localized: """
            There’s no App Preview \(position): \(locale.name) has \(content.slots.count) on \(display.title). Leave position out to add one.
            """), target: target)
        }
        let data = (try? Data(contentsOf: URL(fileURLWithPath: upload.file.path), options: .mappedIfSafe)) ?? Data()
        let video = ProductPageChosenVideo(fileName: upload.file.fileName, data: data, pixelSize: upload.pixelSize, seconds: upload.seconds)
        let kept = position == nil ? content.slots.count : content.slots.count - 1
        let problems = ProductPageVideoCheck.problems([video], displayType: display, kept: kept)
        guard problems.isEmpty else { return .refused(problems.joined(separator: " "), target: target) }
        if let position {
            content.replace(at: position - 1, with: upload.file, proposedBy: context.clientName)
        } else {
            content.add([upload.file], proposedBy: context.clientName)
        }
        let liveCount = liveSet?.previews?.count ?? liveSet?.previewCount ?? 0
        let change = try AppPreviewHandChange.change(
            content, localeName: locale.name, liveCount: liveCount, source: context.source, reason: arguments.string("reason")
        )
        workspace.changes.upsert(change)
        workspace.changes.attach(layers, to: change.id)
        uploads.remove(id: fileID)
        let result: [String: JSONValue] = [
            "status": "queued",
            "changeId": .string(change.id),
            "appPreviews": .int(content.slots.count),
            "showsIn": .string("Review & Push, and Screenshots → \(locale.name) → \(display.title) → App Previews"),
            "next": "The person reviews and pushes it: uploads first, then deletes, then the order. Never push it yourself.",
        ]
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// `{locale, displayType, appPreviews: [{position, fileName, madeBy}],
    /// deletedOnPush}`: the set as it ends after the push, for
    /// `get_screenshot_context`.
    static func json(app: StoreApp, locale: StoreLocale, displayType: ScreenshotDisplayType, in workspace: MCPWorkspace) async throws -> JSONValue {
        let queued = AppPreviewHandChange.queued(in: workspace.changes, appID: app.id, locale: locale.code, displayType: displayType)
        var content = queued.flatMap(AppPreviewHandChange.content)
        if content == nil {
            let (context, live) = try await read(app, in: workspace)
            content = context.localizations.first { $0.key.code == locale.code }.map { localization in
                .start(
                    appID: app.id, localizationID: localization.value, locale: locale.code, displayType: displayType,
                    live: live.previewSets.first { $0.locale == locale.code && $0.displayType == displayType }
                )
            }
        }
        guard let content else { return .null }
        let previews = content.slots.enumerated().map { index, slot -> JSONValue in
            let madeBy = slot.file == nil ? "live" : slot.proposedBy == nil ? "file" : "suggested"
            return ["position": .int(index + 1), "fileName": .string(slot.fileName), "madeBy": .string(madeBy)]
        }
        return [
            "locale": .string(locale.code), "displayType": .string(displayType.mcpValue), "appPreviews": .array(previews),
            "deletedOnPush": .int(content.deletedIDs.count),
        ]
    }

    /// The version's localizations and what's live, as the Screenshots view
    /// reads them.
    static func read(_ app: StoreApp, in workspace: MCPWorkspace) async throws -> (ScreenshotsContext, LiveScreenshots) {
        let storePage = workspace.services.storePage
        do {
            let content = try await storePage.content(for: app, versionID: nil)
            var context = ScreenshotsContext(content: content)
            await context.readPlatformLocalizations(in: content) { id in try await storePage.content(for: app, versionID: id) }
            return try await (context, workspace.services.screenshots.liveScreenshots(for: app, context: context))
        } catch {
            throw MCPToolError.unavailable(String(localized: "Couldn’t read \(app.name)’s App Previews on the App Store: \(error.localizedDescription)"))
        }
    }
}

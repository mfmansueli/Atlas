//
//  GetScreenshotContextTool.swift
//  Atlas
//

import Foundation

/// `get_screenshot_context`: what an assistant needs before captioning:
/// display types and sizes, slot names, the locales in scope, the primary
/// captions, the listing's name and subtitle, and the template version;
/// with a locale and device, that set's screenshots in order.
struct GetScreenshotContextTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "get_screenshot_context",
        title: "Get screenshot context",
        description: """
        Reads what an app's localized App Store screenshots are made of in Atlas: the display types \
        templates render (iphone 6.9″, ipad 13″) and their pixel sizes, the slots (numbered from 1) and their \
        names, the locales in scope (each gets its own screenshots), the primary locale's captions, the \
        listing's name and subtitle, and the template version. Captions are short marketing headlines drawn \
        above or below a real screenshot of the app; they must fit the template, so check them with \
        measure_caption before proposing. fileUploadURL and fileSizes are for propose_screenshot_file (a file for \
        one screenshot, never scaled); setsChangedByHand lists the sets the person changed by hand. Pass locale and \
        displayType to read that set as the language page shows it (`set`): each screenshot's position (from 1), id and \
        what made it (template, a file, or live on the App Store), for propose_screenshot_file, \
        propose_screenshot_removal and propose_screenshot_order. appPreviewUploadURL is for propose_app_preview_file \
        (an App Preview video for iphone or ipad); with locale and displayType, `appPreviews` lists that set's App \
        Previews by position.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "version": MCPToolDefinition.string("The version string, e.g. 1.4. Leave it out for the version being prepared."),
                "locale": MCPToolDefinition.string("With displayType: the language whose set to list, e.g. de-DE."),
                "displayType": MCPToolDefinition.string("With locale: iphone, iphone_duo, ipad, mac, watch or vision_pro."),
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let appID = try arguments.string("appId")
        let draft = try await MCPScreenshotsDraft.load(app: appID, in: context.workspace)
        let document = draft.document
        let listing = try? await MCPListingDraft.load(app: appID, in: context.workspace)
        let slots = (0..<document.slotCount).map { slot -> JSONValue in
            var entry: [String: JSONValue] = ["slot": .int(slot + 1), "name": .string(document.slotName(slot))]
            if let caption = document.captions.caption(locale: draft.primary.code, slot: slot) {
                entry["primaryHeadline"] = .string(caption.headline)
                if let subhead = caption.visibleSubhead { entry["primarySubhead"] = .string(subhead) }
            }
            return .object(entry)
        }
        var result: [String: JSONValue] = [
            "appId": .string(draft.app.id),
            "app": .string(draft.app.name),
            "primaryLocale": .string(draft.primary.code),
            "displayTypes": .array(document.renderedDisplays.map(\.mcpJSON)),
            "slots": .array(slots),
            "localesInScope": .array(draft.scopeLocales.map { ["code": .string($0.code), "name": .string($0.name)] }),
            "templateVersion": document.history.map { .int($0.currentNumber) } ?? .null,
            "hasCaptures": .bool(!document.captures.isEmpty),
        ]
        // Screenshots by hand: where to send a file for propose_screenshot_file,
        // the sizes each device takes, and the sets the person changed.
        result["fileUploadURL"] = .string(MCPEndpoint.screenshotFileUploadURL(
            port: context.port, token: ScreenshotHandUploads.shared.token, appID: draft.app.id
        ))
        result["appPreviewUploadURL"] = .string(MCPEndpoint.appPreviewFileUploadURL(
            port: context.port, token: AppPreviewUploads.shared.token, appID: draft.app.id
        ))
        result["fileSizes"] = .object(Dictionary(uniqueKeysWithValues: ScreenshotDisplayType.studio.map { display in
            (display.mcpValue, JSONValue.array(ScreenshotHandSizes.accepted(on: display).map { .string($0.title) }))
        }))
        if let sets = document.handSets, !sets.isEmpty {
            result["setsChangedByHand"] = .array(sets.map { set in
                [
                    "locale": .string(set.locale), "displayType": .string(set.displayType.mcpValue), "screenshots": .int(set.keptCount),
                    "deletedOnPush": .int(set.slots.count { $0.isDeleted }),
                    "files": .array(set.kept.enumerated().compactMap { index, slot in
                        slot.file.map { ["position": .int(index + 1), "fileName": .string($0.fileName)] }
                    }),
                ]
            })
        }
        if let code = try arguments.optionalString("locale") {
            let display = try MCPScreenshotHandSet.displayType(arguments.optionalString("displayType") ?? ScreenshotDisplayType.iPhone.mcpValue)
            let set = try await MCPScreenshotHandSet.load(draft, locale: draft.locale(code), displayType: display, in: context.workspace)
            result["set"] = set.json
            if AppPreviewSpec.displayTypes.contains(display) {
                result["appPreviews"] = try? await ProposeAppPreviewFileTool.json(
                    app: draft.app, locale: draft.locale(code), displayType: display, in: context.workspace
                )
            }
        }
        if let listing {
            result["version"] = listing.versionJSON
            result["listing"] = [
                "name": .string(listing.listing.value(.name, in: draft.primary)),
                "subtitle": .string(listing.listing.value(.subtitle, in: draft.primary)),
            ]
        }
        return .read(.object(result), target: draft.target)
    }
}

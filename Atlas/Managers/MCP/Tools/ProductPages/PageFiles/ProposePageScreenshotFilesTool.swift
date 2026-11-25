//
//  ProposePageScreenshotFilesTool.swift
//  Atlas
//

import Foundation

/// `propose_page_screenshot_files`: a custom product page's own
/// screenshots in one language on one device, from files the assistant
/// already has, as the page's Choose Files… adds them: checked like Apple
/// checks them (count, sizes, PNG or JPEG), kept on this Mac and queued in
/// Review & Push as one change, in place of a set queued before for that
/// language and device. The default page's screenshots don't change.
struct ProposePageScreenshotFilesTool: MCPTool {
    var store = ProductPagesStore.shared
    var analytics = AnalyticsStore.shared
    var uploads: ScreenshotHandUploads = .shared
    var folder: ProductPageFilesFolder = .shared

    let definition = MCPToolDefinition(
        name: "propose_page_screenshot_files",
        title: "Propose a product page's screenshot files",
        description: """
        Gives a custom product page its own screenshots in one language on one device (iphone or ipad), from files \
        you have, as the page's Choose Files… does: send each PNG or JPEG to get_screenshot_context's fileUploadURL \
        first (curl -s --data-binary @01.png -H 'Content-Type: image/png' '<fileUploadURL>?name=01.png') and pass \
        the fileIds in order (at most 10). Each must be one of the device's App Store sizes, upright or turned: Atlas \
        never scales a screenshot, and a wrong size or count is refused with what to use. The set waits in Review & \
        Push as one change, replacing a set queued before for that language and device; the default page's \
        screenshots don't change. A page with App Review takes nothing. To have Atlas lay screenshots out from \
        captures instead, use propose_page_screenshots.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "pageId": MCPToolDefinition.string("The page's id from get_product_pages."),
                "locale": MCPToolDefinition.string("The language, e.g. de-DE: one of the default page's."),
                "device": ["type": "string", "enum": ["iphone", "ipad"], "description": "iphone or ipad."],
                "fileIds": ["type": "array", "items": ["type": "string"], "description": "The fileIds the upload link returned, in order."],
                "reason": MCPToolDefinition.why("Why, for the person."),
            ]),
            required: ["appId", "pageId", "locale", "device", "fileIds", "reason"]
        ),
        proposalKind: .screenshots
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let section = String(localized: "\(app.name) · Custom Product Pages", comment: "kind:other")
        guard context.allows(.screenshots) else { return .refused(MCPProposalKind.screenshots.refusal, target: section) }
        let state = try await MCPProductPages.load(app: app, workspace: context.workspace, store: store, analytics: analytics)
        let pageID = try arguments.string("pageId")
        guard let page = state.page(pageID), !page.isDraft else {
            throw MCPToolError.notFound(String(localized: """
            \(app.name) has no product page “\(pageID)” in App Store Connect. Use the ids get_product_pages lists; a draft gets \
            screenshots once it’s pushed.
            """, comment: "kind:error"))
        }
        let device = try Self.device(arguments.string("device"))
        let localeCode = try arguments.string("locale")
        let target = "\(section) · \(page.name) · \(localeCode) · \(device.title)"
        if let refusal = Self.refusal(page: page, state: state) { return .refused(refusal, target: target) }
        guard let locale = state.locale(localeCode) else {
            return .refused(String(localized: "\(localeCode) isn’t one of the default page’s languages, so the page can’t have it.", comment: "kind:error"), target: target)
        }
        let reason = try arguments.string("reason")
        let ids = try arguments.optionalStrings("fileIds") ?? []
        let read = try readFiles(ids, appID: app.id, in: context.workspace)
        if !read.missing.isEmpty {
            return .refused(String(localized: """
            No upload \(read.missing.joined(separator: ", ")) for \(app.name) in this launch. Send each file to \
            get_screenshot_context’s fileUploadURL first and pass the fileIds it returns.
            """, comment: "kind:error"), target: target)
        }
        let problems = ProductPageFileCheck.problems(read.files, device: device)
        guard problems.isEmpty else { return .refused(problems.joined(separator: " "), target: target) }
        let saved: [ProductPageScreenshotsPush.File]
        do {
            saved = try folder.save(read.files, appID: app.id)
        } catch {
            throw MCPToolError.unavailable(String(localized: "The screenshots couldn’t be copied: \(error.localizedDescription)", comment: "kind:error"))
        }
        let displayType = device.displayType
        let hadOwn = page.localization(locale)?.screenshotDisplayTypes.contains(displayType.apiValue) ?? false
        let change = state.builder.screenshotsChange(saved, locale: locale, displayType: displayType, of: page, hadOwn: hadOwn, source: context.source)
        context.workspace.changes.upsert(change)
        let layers = try SuggestionLayers(details: arguments.optionalString("details") ?? reason, confidence: arguments.layers()?.confidence)
        context.workspace.changes.attach(layers, to: change.id)
        ids.forEach(uploads.remove)
        let result: JSONValue = [
            "status": "queued",
            "changeId": .string(change.id),
            "screenshots": .int(saved.count),
            "next": "It waits in Review & Push; the person pushes it. Never push it yourself.",
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    static func device(_ value: String) throws -> ProductPageDevice {
        switch value.lowercased().replacingOccurrences(of: "_", with: "") {
        case "iphone": .iPhone
        case "ipad": .iPad
        default: throw MCPToolError.invalidArgument(name: "device", expected: "iphone or ipad")
        }
    }

    /// Why the page takes no screenshots now; nil when it does.
    static func refusal(page: ProductPage, state: MCPProductPages) -> String? {
        if state.archive.keyCannotChange {
            return String(localized: "The API key can read product pages but not change them.", comment: "kind:error")
        }
        if page.editing?.state.isLocked == true {
            return String(localized: "“\(page.name)” is with App Review: nothing on it can change until Apple is done.", comment: "kind:error")
        }
        return nil
    }

    /// The uploads as files the page's check reads, and the ids not found.
    private func readFiles(_ ids: [String], appID: StoreApp.ID, in workspace: MCPWorkspace) throws -> (files: [ProductPageChosenFile], missing: [String]) {
        var files: [ProductPageChosenFile] = []
        var missing: [String] = []
        for id in ids.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) {
            guard let upload = uploads.upload(id: id, appID: appID),
                  let data = try? workspace.services.screenshots.handFiles.data(for: upload.file, appID: appID)
            else {
                missing.append(id)
                continue
            }
            files.append(ProductPageChosenFile(fileName: upload.file.fileName, data: data, pixelSize: upload.file.pixelSize))
        }
        return (files, missing)
    }
}

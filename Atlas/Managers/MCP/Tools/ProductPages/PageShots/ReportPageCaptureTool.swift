//
//  ReportPageCaptureTool.swift
//  Atlas
//

import Foundation

/// `report_page_capture`: a screen of the default set captured again for a
/// page (board 52, Capture Screens Again), sent to the run's upload link
/// first. Atlas checks it's the device's full size and lays the page's set
/// out with it; the default page's capture doesn't change.
struct ReportPageCaptureTool: MCPTool {
    var studio = PageShotsStudio.shared

    static let maxNotes = 200

    let definition = MCPToolDefinition(
        name: "report_page_capture",
        title: "Report a screen captured again for a product page",
        description: """
        Names a capture of one of the default set's screens, taken again for a custom product page when the person \
        turned on Capture Screens Again in Make Screenshots for This Page (get_page_screenshots' recapture): the screen \
        (its number from 1), the locale the app ran in, displayType (iphone or ipad) and the upload ID the upload link \
        returned for its PNG, with what it shows now. The PNG must be the device's full size: 1320 × 2868 on iPhone, \
        2064 × 2752 on iPad. A screen sent again in the same language on the same device takes the place of the one \
        before; at most three screens are captured again. A language without its own capture uses the primary \
        language's. The default page's captures never change.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "page": MCPToolDefinition.string("The page's name or id, as get_page_screenshots has it."),
                "screen": ["type": "integer", "description": "One of the default set's screens, from 1, as get_page_screenshots lists them."],
                "locale": MCPToolDefinition.string("The locale the app ran in, e.g. de-DE."),
                "displayType": MCPToolDefinition.string("iphone or ipad."),
                "upload": MCPToolDefinition.string("The upload ID the upload link returned."),
                "notes": MCPToolDefinition.string("What the screen shows now, e.g. “The diary locked with Face ID”."),
            ],
            required: ["appId", "page", "screen", "locale", "displayType", "upload"]
        ),
        proposalKind: .screenshots
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let found: PageShotsMCPRun
        switch try await PageShotsMCPRun.find(arguments, in: context, studio: studio) {
        case let .success(run): found = run
        case let .failure(refusal): return refusal.outcome
        }
        let run = found.run
        if let problem = found.source.problem { return .refused(problem, target: found.target) }
        guard run.recapture != nil else {
            return .refused(String(localized: """
            The person didn’t turn on Capture Screens Again for this page, so its set uses the default page’s captures.
            """), target: found.target)
        }
        if run.stage == .making {
            return .refused(String(localized: "Atlas is laying out the set the person started. Wait until it's done."), target: found.target)
        }
        let target = try target(arguments, found: found)
        let id = try arguments.string("upload").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let upload = studio.uploads[id], upload.runID == run.id else {
            throw MCPToolError.notFound(String(localized: """
            No upload “\(id)” for this page. Send the PNG to get_page_screenshots’ recapture.uploadURL first, and pass \
            the ID it returns.
            """))
        }
        do {
            try AutopilotCenter.checkSize(upload.file.pixelSize, for: target.display)
        } catch {
            return .refused(error.localizedDescription, target: found.target)
        }
        let expected = found.source.captureSize(for: target.display)
        guard upload.file.pixelSize.isLandscape == expected.isLandscape else {
            let way = expected.isLandscape ? String(localized: "landscape") : String(localized: "portrait")
            return .refused(String(localized: """
            This page’s set is \(way) on \(target.display.deviceName), so a \(upload.file.pixelSize.title) capture would be \
            cropped. Turn the simulator \(way) and capture it at \(expected.title).
            """), target: found.target)
        }
        let notes = try String((arguments.optionalString("notes") ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxNotes))
        let capture = PageShotsNewCapture(
            slot: target.slot, locale: target.locale, displayType: target.display, captureID: upload.file.id,
            pixelSize: upload.file.pixelSize, notes: notes, receivedAt: .now
        )
        if let why = studio.receive(capture: capture, for: run.key) { return .refused(why, target: found.target) }
        studio.uploads[id] = nil
        let updated = studio.run(run.key) ?? run
        let result: [String: JSONValue] = [
            "status": "received",
            "captured": GetPageScreenshotsTool.capturesJSON(updated.recapture?.captures ?? []),
            "next": .string(next(updated, slot: target.slot, display: target.display)),
        ]
        let line = MCPToolOutcome.LogLine(target: "\(found.target) · \(target.slot + 1)", outcome: .proposed)
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [line])
    }

    private struct Target {
        var slot: Int
        var locale: String
        var display: ScreenshotDisplayType
    }

    private func target(_ arguments: MCPToolArguments, found: PageShotsMCPRun) throws -> Target {
        let number = arguments.values["screen"]?.intValue ?? 0
        guard number >= 1, number <= found.source.slotCount else {
            throw MCPToolError.invalidArgument(name: "screen", expected: String(localized: "a screen from 1 to \(found.source.slotCount)"))
        }
        let code = try arguments.string("locale")
        guard let locale = StoreLocaleCatalog.resolve(code).locale?.code, found.run.languages.contains(locale) else {
            let list = found.run.languages.formatted(.list(type: .or))
            throw MCPToolError.invalidArgument(name: "locale", expected: String(localized: "one of the page’s languages: \(list)"))
        }
        let value = try arguments.string("displayType")
        guard let display = ScreenshotDisplayType(mcpValue: value), found.run.displays.contains(display) else {
            let list = found.run.displays.map(\.mcpValue).formatted(.list(type: .or))
            throw MCPToolError.invalidArgument(name: "displayType", expected: list)
        }
        return Target(slot: number - 1, locale: locale, display: display)
    }

    /// The languages the set is made in that this screen has no capture of
    /// yet on the device.
    private func next(_ run: PageShotsRun, slot: Int, display: ScreenshotDisplayType) -> String {
        let captured = Set(run.recapture?.captures.filter { $0.slot == slot && $0.displayType == display }.map(\.locale) ?? [])
        let missing = run.locales.filter { !captured.contains($0) }
        guard missing.isEmpty else {
            let list = missing.formatted(.list(type: .and))
            return String(localized: """
            Capture screen \(slot + 1) in \(list) too, so each shows its own language; until then they use the primary \
            language’s.
            """)
        }
        return String(localized: "Done with screen \(slot + 1). Atlas lays the set out with it when the person starts Autopilot.")
    }
}

//
//  ProposeEventArtworkTool.swift
//  Atlas
//

import Foundation

/// `propose_event_artwork`: queues an event's card and/or details page for
/// some or all of its languages, one Review & Push change each. Each file
/// is checked again first; one with a refusal isn't queued. The changes
/// wait for the person to accept them in the event's media card (or in
/// Review & Push), and pushing uploads the art and replaces what that
/// asset type had. Nothing reaches App Store Connect from here.
struct ProposeEventArtworkTool: MCPTool {
    /// Where the files are kept; tests use their own folder.
    var directory = InAppEventArtworkFiles.directory

    let definition = MCPToolDefinition(
        name: "propose_event_artwork",
        title: "Propose In-App Event artwork",
        description: """
        Queues an In-App Event's card (16:9) and/or details page (9:16), checked with render_event_artwork first. \
        `artwork` is a list of {kind: card|details, fileId, locales, posterSeconds}: `fileId` from render_event_artwork \
        or the upload link; `locales` the event's languages to upload it into (left out: every language the event has; \
        Apple shows the primary language's art in a language without its own, so the primary language alone is often \
        enough); `posterSeconds` a video's poster frame. Each file is checked again: one with a refusal isn't queued, \
        and a language the event doesn't have yet is skipped (add its texts with propose_event_texts first). Each \
        language becomes one change in Review & Push that waits for the person to look at it and accept it in the \
        event's media card; pushing uploads it and replaces that language's card or details page. Proposing the same \
        kind and language again replaces the waiting one. Nothing is pushed or submitted for review here.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "eventId": MCPToolDefinition.string("The event's id, from get_in_app_events."),
                "artwork": [
                    "type": "array", "description": "{kind, fileId, locales, posterSeconds} objects: a card, a details page, or both.",
                    "items": ["type": "object"],
                ],
            ],
            required: ["appId", "eventId", "artwork"]
        ),
        proposalKind: .screenshots
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let event = try await RenderEventArtworkTool.event(arguments.string("eventId"), of: app, in: context)
        let target = "\(app.name) · \(event.referenceName) · artwork"
        guard context.allows(.screenshots) else { return .refused(MCPProposalKind.screenshots.refusal, target: target) }
        if let reason = Self.lockedReason(event) { return .refused(reason, target: target) }
        let builder = InAppEventChangeBuilder(appID: app.id)
        let language = event.primaryLocale ?? event.localizations.first?.locale ?? "en-US"
        var changes: [PendingChange] = []
        var refused: [JSONValue] = []
        var warnings: [JSONValue] = []
        var seen: Set<String> = []
        for item in try arguments.array("artwork") {
            let fileID = item["fileId"]?.stringValue ?? ""
            guard let kind = item["kind"]?.stringValue.flatMap(InAppEventMedia.Kind.init(mcpValue:)) else {
                refused.append(["fileId": .string(fileID), "reason": "kind is card or details."])
                continue
            }
            guard let report = await InAppEventArtworkReport.make(
                fileID: fileID, appID: app.id, kind: kind, language: language, posterSeconds: item["posterSeconds"]?.doubleValue ?? 0,
                in: directory
            ) else {
                refused.append(["kind": .string(kind.mcpValue), "fileId": .string(fileID), "reason": .string(Self.missingFile(fileID))])
                continue
            }
            guard report.canQueue else {
                refused.append([
                    "kind": .string(kind.mcpValue), "fileId": .string(fileID),
                    "reason": .string(report.checks.filter(\.isRefusal).map(\.text).joined(separator: " ")),
                ])
                continue
            }
            warnings += report.checks.filter { !$0.isRefusal }.map { ["kind": .string(kind.mcpValue), "fileId": .string(fileID), "warning": .string($0.text)] }
            let (localizations, skipped) = Self.localizations(item["locales"], of: event)
            refused += skipped.map { ["kind": .string(kind.mcpValue), "locale": .string($0.locale), "reason": .string($0.reason)] }
            for localization in localizations where seen.insert("\(kind.rawValue) \(localization.locale)").inserted {
                changes.append(builder.artworkChange(report, into: localization, of: event, source: .assistant(client: context.clientName)))
            }
        }
        guard !changes.isEmpty else {
            return .refused("Nothing could be queued.", target: target, details: ["refused": .array(refused), "warnings": .array(warnings)])
        }
        context.workspace.changes.upsert(contentsOf: changes)
        return MCPToolOutcome(
            result: [
                "status": "queued",
                "changes": .array(changes.map { ["changeId": .string($0.id), "title": .string($0.title)] }),
                "refused": .array(refused),
                "warnings": .array(warnings),
                "showsIn": .string("In-App Events (⌘4) → \(event.referenceName) → Images and video, and Review & Push"),
                "next": "The person looks at it and accepts it; pushing uploads it. Never push or submit it yourself.",
            ],
            isError: false,
            logLines: changes.map { MCPToolOutcome.LogLine(target: "\(app.name) · \(event.referenceName) · \($0.title)", outcome: .proposed) }
                + refused.map { MCPToolOutcome.LogLine(target: target, outcome: .refused, reason: $0["reason"]?.stringValue) }
        )
    }

    /// Why the event takes no new art now; nil when it does.
    static func lockedReason(_ event: InAppEvent) -> String? {
        switch event.state {
        case .waitingForReview, .inReview:
            "“\(event.referenceName)” is with App Review: its art can change once the review is over."
        case .past, .archived:
            "“\(event.referenceName)” is over: its art can’t change any more."
        case .draft, .readyForReview, .rejected, .accepted, .approved, .published:
            nil
        }
    }

    /// The localizations `locales` names (every one when it's left out),
    /// and the codes the event doesn't have.
    static func localizations(_ locales: JSONValue?, of event: InAppEvent) -> ([InAppEventLocalization], [(locale: String, reason: String)]) {
        let codes: [String]? = locales?.stringValue.map { [$0] } ?? locales?.arrayValue?.compactMap(\.stringValue)
        guard let codes, !codes.isEmpty, codes != ["all"] else { return (event.localizations, []) }
        var found: [InAppEventLocalization] = []
        var skipped: [(locale: String, reason: String)] = []
        for code in codes {
            if let localization = event.localization(code) {
                found.append(localization)
            } else {
                skipped.append((code, "The event has no \(code) language yet: add its texts with propose_event_texts first, then its art."))
            }
        }
        return (found, skipped)
    }

    static func missingFile(_ fileID: String) -> String {
        fileID.isEmpty
            ? "fileId is missing: render the art with render_event_artwork, or send the file to the upload link."
            : "Atlas has no file “\(fileID)” it can read: render it with render_event_artwork or send it to the upload link again."
    }
}

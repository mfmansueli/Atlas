//
//  ProposeEventArtworkTool.swift
//  Atlas
//

import Foundation

/// `propose_event_artwork`: queues an event's card and/or details page for
/// its primary language (by default) or the languages named, one Review &
/// Push change each. Each file is checked again first; one with a refusal
/// isn't queued. A language that would get the primary language's art over
/// again isn't given a copy: Apple shows the primary's there already. The
/// changes wait for the person to accept them in the event's media card
/// (or in Review & Push), and pushing uploads the art and replaces what
/// that asset type had. Nothing reaches App Store Connect from here.
struct ProposeEventArtworkTool: MCPTool {
    /// Where the files are kept; tests use their own folder.
    var directory = InAppEventArtworkFiles.directory

    let definition = MCPToolDefinition(
        name: "propose_event_artwork",
        title: "Propose In-App Event artwork",
        description: """
        Queues an In-App Event's card (16:9) and/or details page (9:16), checked with render_event_artwork first. \
        `artwork` is a list of {kind: card|details, fileId, locales, posterSeconds}: `fileId` from render_event_artwork \
        or the upload link; `locales` the languages to upload it into, left out: the event's primary language only \
        (Apple shows the primary language's art in every language without its own), "all": every language the event \
        has; `posterSeconds` a video's poster frame. A language whose texts wait in Review & Push as new \
        (get_in_app_events' queuedTexts with newLanguage) can be named too: its upload waits for the push to create \
        it. The same file as the primary language's art (same SHA-256, queued or already in App Store Connect) isn't \
        queued again for a language that has no card or details page of its own: `sameAsPrimary` lists those, as they \
        show the primary's already; it is queued where it replaces the language's own art or other art waiting for \
        it. Each file is checked again: one with a refusal isn't queued, and a language the event doesn't have yet is \
        skipped (add its texts with propose_event_texts first). Each language becomes one change in Review & Push that \
        waits for the person to look at it and accept it in the event's media card; pushing uploads it and replaces \
        that language's card or details page. Proposing the same kind and language again replaces the waiting one. \
        `status` is queued, notNeeded (every language named already shows it) or refused. Nothing is pushed or \
        submitted for review here.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withConfidence([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "eventId": MCPToolDefinition.string("The event's id, from get_in_app_events."),
                "artwork": [
                    "type": "array",
                    "description": """
                    {kind, fileId, locales, posterSeconds} objects: a card, a details page, or both. locales: a list of \
                    codes, or "all"; left out, the primary language.
                    """,
                    "items": ["type": "object"],
                ],
            ]),
            required: ["appId", "eventId", "artwork"]
        ),
        proposalKind: .artwork
    )

    /// One checked file for one language.
    private struct Target {
        var report: InAppEventArtworkReport
        var locale: String
    }

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let event = try await RenderEventArtworkTool.event(arguments.string("eventId"), of: app, in: context)
        let target = "\(app.name) · \(event.referenceName) · artwork"
        guard context.allows(.screenshots) else { return .refused(MCPProposalKind.screenshots.refusal, target: target) }
        if let reason = Self.lockedReason(event) { return .refused(reason, target: target) }
        let builder = InAppEventChangeBuilder(appID: app.id)
        let primary = event.primaryLocalization?.locale ?? "en-US"
        let queue = context.workspace.changes
        let queuedChanges = queue.changes(for: app.id, section: .inAppEvents)
        let newLanguages = Set(builder.newLanguages(of: event.id, in: queuedChanges)).subtracting(event.localizations.map(\.locale))
        var targets: [Target] = []
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
                fileID: fileID, appID: app.id, kind: kind, language: primary, posterSeconds: item["posterSeconds"]?.doubleValue ?? 0,
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
            let (locales, skipped) = Self.locales(item["locales"], of: event, newLanguages: newLanguages)
            refused += skipped.map { ["kind": .string(kind.mcpValue), "locale": .string($0.locale), "reason": .string($0.reason)] }
            for locale in locales where seen.insert("\(kind.rawValue) \(locale)").inserted {
                targets.append(Target(report: report, locale: locale))
            }
        }
        let (changes, sameAsPrimary) = queueable(targets, event: event, builder: builder, queued: queuedChanges, source: context.source)
        guard !changes.isEmpty else {
            let details: [String: JSONValue] = ["refused": .array(refused), "warnings": .array(warnings), "sameAsPrimary": .array(sameAsPrimary)]
            guard refused.isEmpty, !sameAsPrimary.isEmpty else { return .refused("Nothing could be queued.", target: target, details: details) }
            var result = details
            result["status"] = "notNeeded"
            result["next"] = "Nothing to queue: those languages already show the primary language's art. Never push or submit it yourself."
            return MCPToolOutcome(result: .object(result), isError: false, logLines: [MCPToolOutcome.LogLine(target: target, outcome: .read)])
        }
        queue.upsert(contentsOf: changes)
        try queue.attach(arguments.layers(), to: changes.map(\.id))
        var result: [String: JSONValue] = [
            "status": "queued",
            "changes": .array(changes.map { ["changeId": .string($0.id), "title": .string($0.title)] }),
            "refused": .array(refused),
            "warnings": .array(warnings),
            "showsIn": .string("In-App Events (⌘5) → \(event.referenceName) → Images and video, and Review & Push"),
            "next": "The person looks at it and accepts it; pushing uploads it. Never push or submit it yourself.",
        ]
        if !sameAsPrimary.isEmpty { result["sameAsPrimary"] = .array(sameAsPrimary) }
        return MCPToolOutcome(
            result: .object(result),
            isError: false,
            logLines: changes.map { MCPToolOutcome.LogLine(target: "\(app.name) · \(event.referenceName) · \($0.title)", outcome: .proposed) }
                + refused.map { MCPToolOutcome.LogLine(target: target, outcome: .refused, reason: $0["reason"]?.stringValue) }
        )
    }

    /// The changes for `targets`, less the copies of the primary language's
    /// art that a language shows anyway (`sameAsPrimary`, with why).
    private func queueable(
        _ targets: [Target], event: InAppEvent, builder: InAppEventChangeBuilder, queued changes: [PendingChange], source: ChangeSource
    ) -> (changes: [PendingChange], sameAsPrimary: [JSONValue]) {
        let queued = builder.queuedArtwork(for: event.id, in: changes)
        let infos = InAppEventArtworkFiles.infos(atPaths: queued.map(\.push.path) + targets.map { $0.report.url.path(percentEncoded: false) })
        let fingerprint = { (report: InAppEventArtworkReport) in
            InAppEventArtworkFingerprint(report, info: infos[report.url.path(percentEncoded: false)])
        }
        let primary = event.primaryLocalization?.locale
        let proposed = Dictionary(targets.filter { $0.locale == primary }.map { ($0.report.kind, fingerprint($0.report)) }) { first, _ in first }
        let copies = InAppEventArtworkCopies(
            event: event, queued: queued, infos: infos, stored: InAppEventArtworkFiles.stored(appID: builder.appID, in: directory), proposed: proposed
        )
        var result: [PendingChange] = []
        var sameAsPrimary: [JSONValue] = []
        for target in targets {
            let kind = target.report.kind
            guard copies.needsQueuing(fingerprint(target.report), kind: kind, locale: target.locale, queued: queued, infos: infos) else {
                var note = "\(target.locale) has no \(kind.name) of its own, so it shows \(primary ?? "the primary language")'s, which is this file: no copy queued."
                if let waiting = queued.first(where: { $0.kind == kind && $0.locale == target.locale }) {
                    note += " The same file already waits for it (\(waiting.changeID)); the person can take that out too."
                }
                sameAsPrimary.append([
                    "kind": .string(kind.mcpValue), "locale": .string(target.locale), "fileId": .string(target.report.fileID), "note": .string(note),
                ])
                continue
            }
            let change = if let localization = event.localization(target.locale) {
                builder.artworkChange(target.report, into: localization, of: event, source: source)
            } else {
                builder.artworkChange(target.report, newLanguage: target.locale, of: event, source: source)
            }
            result.append(change)
        }
        return (result, sameAsPrimary)
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

    /// The languages `locales` names: the primary one when it's left out,
    /// every one the event has for "all", and the codes neither the event
    /// nor its queued texts (`newLanguages`) have, as skipped.
    static func locales(
        _ locales: JSONValue?, of event: InAppEvent, newLanguages: Set<String> = []
    ) -> (locales: [String], skipped: [(locale: String, reason: String)]) {
        let codes: [String]? = locales?.stringValue.map { [$0] } ?? locales?.arrayValue?.compactMap(\.stringValue)
        guard let codes, !codes.isEmpty else { return (event.primaryLocalization.map { [$0.locale] } ?? [], []) }
        guard codes != ["all"] else { return (event.localizations.map(\.locale), []) }
        var found: [String] = []
        var skipped: [(locale: String, reason: String)] = []
        for code in codes {
            if event.localization(code) != nil || newLanguages.contains(code) {
                found.append(code)
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

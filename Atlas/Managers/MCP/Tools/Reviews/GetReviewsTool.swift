//
//  GetReviewsTool.swift
//  Atlas
//

import Foundation

struct GetReviewsTool: MCPTool {
    var store = ReviewsStore.shared
    var autoReply = AutoReplyCenter.shared

    static let defaultLimit = 60
    static let maximumLimit = 200

    let definition = MCPToolDefinition(
        name: "get_reviews",
        title: "Get App Store reviews",
        description: """
        Reads an app's written App Store reviews from every country, newest first: each with its id, territory, rating, \
        title and body as written, the language Atlas detected, the version reviewed, the reply already on the App \
        Store (if any) and a reply already suggested. `show` picks needsReply (default: no reply yet and under 5 stars), \
        low (1–2 stars), replied or all; `limit` is 60 unless given (200 at most). Also returns the counts, the app's \
        current version and the groups sent before. Read-only. Follow with propose_review_replies (one reply per review, \
        in the reviewer's language) and propose_review_themes (the subjects people write about). `ratings` has the App \
        Store's average and count (the storefronts with the most reviews, and the US), the written reviews in all \
        (Apple's count) and starsOnly, the ratings that came without a written review; those have no text to read. \
        A review whose suggestion the person dismissed has suggestionDismissed; one with a replacement waiting has \
        suggestedReplacement. groupId lists only that group's reviews (and its reviewIds); older: true reads the next \
        page of older reviews from App Store Connect first, as Show More does (olderLeft says whether more exist). \
        autoReply has the person's whole Reply Automatically rule and its history (what went out by itself, newest \
        first), which you can't change.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "show": MCPToolDefinition.string("needsReply (default), low, replied or all."),
                "limit": ["type": "integer", "description": "How many reviews at most. 60 unless given; 200 at most."],
                "groupId": MCPToolDefinition.string("Only the reviews of this group (get_reviews' groups[].id)."),
                "older": ["type": "boolean", "description": "true: read the next page of older reviews from App Store Connect first."],
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let show = try Self.filter(arguments)
        let limit = try min(max(arguments.optionalInt("limit") ?? Self.defaultLimit, 1), Self.maximumLimit)
        await store.refreshIfStale(app, services: context.workspace.services.reviews)
        var notes: [JSONValue] = []
        if try arguments.optionalBool("older") == true {
            await notes.append(Self.readOlder(app, store: store, services: context.workspace.services.reviews))
        }
        let archive = store.archive(for: app.id)
        let target = "\(app.name) · Reviews"
        guard archive.fetchedAt != nil else {
            throw MCPToolError.unavailable(String(localized: """
            Atlas couldn’t read \(app.name)’s reviews from App Store Connect. The person can open Reviews (⌘8) to see why.
            """))
        }
        let ratings = await Self.ratings(of: app, archive: archive, services: context.workspace.services.reviews)
        let group = try Self.group(arguments, in: archive)
        let groupIDs = group.map { Set($0.reviewIDs) }
        let matching = archive.reviews
            .filter { review in groupIDs.map { $0.contains(review.id) } ?? show.includes(review) }
            .sorted { $0.date > $1.date }
        if matching.count > limit { notes.append(.string("\(matching.count - limit) more match; raise limit to read them.")) }
        if archive.next != nil { notes.append("Older reviews exist that Atlas hasn’t read yet: call again with older: true to read the next page.") }
        var result: [String: JSONValue] = [
            "appId": .string(app.id),
            "app": .string(app.name),
            "currentVersion": archive.currentVersion.map(JSONValue.string) ?? .null,
            "counts": [
                "read": .int(archive.reviews.count),
                "needReply": .int(archive.needsReplyCount),
                "repliesSuggested": .int(archive.openSuggestionCount),
                "replacementsSuggested": .int(archive.openReplacementCount),
                "suggestionsDismissed": .int(archive.dismissed.count { archive.suggestions[$0] != nil }),
            ],
            "ratings": ratings,
            "replyLimit": .int(ReviewText.replyLimit),
            "textRules": StoreTextGuidelinePlace.reviewReply.rulesJSON,
            "reviews": .array(matching.prefix(limit).map { ReviewsMCPJSON.review($0, in: archive) }),
            "groups": .array(archive.themes.map(ReviewsMCPJSON.theme)),
            "autoReply": Self.autoReply(autoReply.archive(for: app.id)),
            "olderLeft": .bool(archive.next != nil),
            "notes": .array(notes),
        ]
        if let group { result["group"] = ReviewsMCPJSON.theme(group, includesReviewIDs: true) }
        return .read(.object(result), target: target)
    }

    /// The App Store's average and count, and how many ratings are stars
    /// only, as the Ratings card shows them.
    static func ratings(of app: StoreApp, archive: ReviewsArchive, services: any ReviewsServices) async -> JSONValue {
        let countries = RatingsSummary.countries(for: archive.reviews)
        let store = await services.ratings(for: app, countries: countries)
        let summary = RatingsSummary.make(
            ratings: store, countries: countries, reviews: archive.reviews, writtenCount: archive.writtenCount, version: archive.currentVersion, now: Date()
        )
        return [
            "average": summary.average.map { .double(($0 * 100).rounded() / 100) } ?? .null,
            "count": .int(summary.ratingCount),
            "countries": .int(summary.storefrontCount),
            "written": summary.writtenCount.map(JSONValue.int) ?? .null,
            "starsOnly": summary.starsOnlyCount.map(JSONValue.int) ?? .null,
        ]
    }

    /// Reply Automatically, so the assistant sends what the rule decides
    /// from. It can't change it.
    static func autoReply(_ archive: AutoReplyArchive) -> JSONValue {
        let rule = archive.rule
        let history: JSONValue = .array(archive.history.sorted { $0.sentAt > $1.sentAt }.prefix(historyLimit).map(historyJSON))
        guard rule.isOn else { return ["on": false, "history": history] }
        return [
            "on": true,
            "paused": .bool(rule.isPaused),
            "mode": .string(rule.mode.rawValue),
            "summary": .string(rule.summary),
            "ratings": .array(rule.ratings.sorted().map(JSONValue.int)),
            "languages": .array(rule.languages.sorted().map(JSONValue.string)),
            "waitTopics": .array(rule.waitTopics.map(\.rawValue).sorted().map(JSONValue.string)),
            "delayMinutes": .int(rule.delay.rawValue),
            "dailyCap": .int(rule.dailyCap),
            "onSince": rule.onSince.map { .string($0.formatted(.iso8601)) } ?? .null,
            "tone": .string(rule.tone.rawValue),
            "signature": .string(rule.signature),
            "needYou": .int(archive.needsYouCount),
            "history": history,
            "note": .string(
                "With each reply send waitTopics (bug, billing, account, featureRequest, personal) and unsure. "
                    + "The person's rule decides what goes out; you never send and can't change it."
            ),
        ]
    }

    /// The newest replies Reply Automatically sent, at most this many.
    static let historyLimit = 30

    private static func historyJSON(_ entry: AutoReplyHistoryEntry) -> JSONValue {
        var object: [String: JSONValue] = [
            "reviewId": .string(entry.reviewID),
            "text": .string(entry.text),
            "rating": .int(entry.rating),
            "sentAt": .string(entry.sentAt.formatted(.iso8601)),
            "rule": .string(entry.rule),
        ]
        if let undone = entry.undoneAt { object["undoneAt"] = .string(undone.formatted(.iso8601)) }
        return .object(object)
    }

    /// Show More: the next page of older reviews, kept like the section
    /// keeps it. Returns the note the result carries.
    private static func readOlder(_ app: StoreApp, store: ReviewsStore, services: any ReviewsServices) async -> JSONValue {
        guard let next = store.archive(for: app.id).next else { return "No older reviews: every review is read." }
        let before = store.archive(for: app.id).reviews.count
        do {
            try await store.append(services.reviews(for: app, after: next), for: app.id)
        } catch {
            return .string("Older reviews didn’t load: \(error.localizedDescription)")
        }
        return .string("Read \(store.archive(for: app.id).reviews.count - before) older reviews.")
    }

    private static func group(_ arguments: MCPToolArguments, in archive: ReviewsArchive) throws -> ReviewTheme? {
        guard let id = try arguments.optionalString("groupId") else { return nil }
        guard let theme = archive.themes.first(where: { $0.id == id }) else {
            let ids = archive.themes.map(\.id).formatted(.list(type: .or))
            throw MCPToolError.notFound(archive.themes.isEmpty
                ? "No group “\(id)”: no groups were sent yet."
                : "No group “\(id)”. The groups are \(ids).")
        }
        return theme
    }

    private static func filter(_ arguments: MCPToolArguments) throws -> ReviewFilter {
        switch try arguments.optionalString("show") ?? "needsReply" {
        case "needsReply": .needsReply
        case "low": .lowStars
        case "replied": .replied
        case "all": .all
        default: throw MCPToolError.invalidArgument(name: "show", expected: "needsReply, low, replied or all")
        }
    }
}

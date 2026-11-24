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
        (Apple's count) and starsOnly, the ratings that came without a written review; those have no text to read.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "show": MCPToolDefinition.string("needsReply (default), low, replied or all."),
                "limit": ["type": "integer", "description": "How many reviews at most. 60 unless given; 200 at most."],
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let show = try Self.filter(arguments)
        let limit = try min(max(arguments.optionalInt("limit") ?? Self.defaultLimit, 1), Self.maximumLimit)
        await store.refreshIfStale(app, services: context.workspace.services.reviews)
        let archive = store.archive(for: app.id)
        let target = "\(app.name) · Reviews"
        guard archive.fetchedAt != nil else {
            throw MCPToolError.unavailable(String(localized: """
            Atlas couldn’t read \(app.name)’s reviews from App Store Connect. The person can open Reviews (⌘8) to see why.
            """))
        }
        let ratings = await Self.ratings(of: app, archive: archive, services: context.workspace.services.reviews)
        let matching = archive.reviews.filter { show.includes($0) }.sorted { $0.date > $1.date }
        var notes: [JSONValue] = []
        if matching.count > limit { notes.append(.string("\(matching.count - limit) more match; raise limit to read them.")) }
        if archive.next != nil { notes.append("Older reviews exist that Atlas hasn’t read yet; the person loads them with Show More in Reviews.") }
        let result: JSONValue = [
            "appId": .string(app.id),
            "app": .string(app.name),
            "currentVersion": archive.currentVersion.map(JSONValue.string) ?? .null,
            "counts": [
                "read": .int(archive.reviews.count),
                "needReply": .int(archive.needsReplyCount),
                "repliesSuggested": .int(archive.openSuggestionCount),
            ],
            "ratings": ratings,
            "replyLimit": .int(ReviewText.replyLimit),
            "textRules": StoreTextGuidelinePlace.reviewReply.rulesJSON,
            "reviews": .array(matching.prefix(limit).map { ReviewsMCPJSON.review($0, in: archive) }),
            "groups": .array(archive.themes.map(ReviewsMCPJSON.theme)),
            "autoReply": Self.autoReply(autoReply.rule(for: app.id)),
            "notes": .array(notes),
        ]
        return .read(result, target: target)
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
    static func autoReply(_ rule: AutoReplyRule) -> JSONValue {
        guard rule.isOn else { return ["on": false] }
        return [
            "on": true,
            "paused": .bool(rule.isPaused),
            "tone": .string(rule.tone.rawValue),
            "signature": .string(rule.signature),
            "note": .string(
                "With each reply send waitTopics (bug, billing, account, featureRequest, personal) and unsure. "
                    + "The person's rule decides what goes out; you never send and can't change it."
            ),
        ]
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

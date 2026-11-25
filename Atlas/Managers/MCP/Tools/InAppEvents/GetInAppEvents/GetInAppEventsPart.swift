//
//  GetInAppEventsPart.swift
//  Atlas
//

import Foundation

/// What `get_in_app_events` can include (`include`) besides each event's
/// id, reference name, badge, state, details and dates, which always
/// come. Without `include` it gives every part but the two heaviest,
/// `mediaDetails` (each language's media as App Store Connect gives it)
/// and `design` (the app's look and how to make art), and says how to
/// ask for them: MCP clients cap a tool result's size (Alba's whole answer
/// was 83k characters, saved to a file instead).
enum GetInAppEventsPart: String, CaseIterable, Hashable, Sendable {
    /// Each event's texts per language, the languages missing or
    /// suggested, the suggestions waiting and the texts queued, and the
    /// rules for event texts.
    case texts
    /// Whether each language has its own card and details page, what's
    /// still missing, the art queued, and the upload link.
    case media
    /// Each language's media as App Store Connect gives it.
    case mediaDetails
    /// What App Store Connect still needs before App Review, warnings
    /// about App Review's time, the details and dates queued, whether the
    /// dates can change and whether the project claims the deep link.
    case review
    /// The last check of the deep link in the app's code.
    case deepLinkCheck
    /// What the art is designed from.
    case design
    /// A push in progress and this app's event changes in it.
    case push
    /// The new events waiting in Review & Push.
    case queued
    /// How ended events did, from App Analytics: page views, opens and
    /// downloads, as the event page's Results card shows them.
    case results

    /// Every part but the two heaviest.
    static let standard: Set<Self> = Set(allCases).subtracting([.mediaDetails, .design])

    /// "all" in `include`: every part.
    static let allName = "all"

    /// Every name `include` takes.
    static var names: [String] {
        allCases.map(\.rawValue) + [allName]
    }

    /// The parts `names` asks for: `standard` when nil, every part for
    /// "all". An unknown name throws, listing the known ones.
    static func parts(_ names: [String]?) throws -> Set<Self> {
        guard let names else { return standard }
        var parts: Set<Self> = []
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            if trimmed.caseInsensitiveCompare(allName) == .orderedSame { return Set(allCases) }
            guard let part = allCases.first(where: { $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
                throw MCPToolError.invalidArgument(name: "include", expected: String(localized: "some of \(names.joined(separator: ", "))"))
            }
            parts.insert(part)
        }
        return parts
    }

    /// The keys this part adds to each event.
    var eventKeys: Set<String> {
        switch self {
        case .texts: ["texts", "missingLanguages", "suggestedLanguages", "queuedTexts", "openSuggestions", "staleSuggestions"]
        case .media: ["media", "stillMissing", "queuedArtwork", "queuedArtworkSummary", "identicalCopies", "mediaNote"]
        case .mediaDetails: ["mediaDetails"]
        case .review:
            [
                "missingForReview", "readyForReview", "reviewWarnings", "queuedDetails", "queuedDates", "datesEditable", "datesNotEditable",
                "deepLinkClaim",
            ]
        case .deepLinkCheck: ["deepLinkCheck"]
        case .results: ["results"]
        case .design, .push, .queued: []
        }
    }

    /// The keys this part adds to the result itself.
    var resultKeys: Set<String> {
        switch self {
        case .texts: ["textRules"]
        case .media: ["artworkUpload"]
        case .design: ["design"]
        case .push: ["pushInProgress", "pushChanges"]
        case .queued: ["queued"]
        case .mediaDetails, .review, .deepLinkCheck, .results: []
        }
    }

    /// `object` without the keys of the parts left out of `parts`.
    static func keeping(_ parts: Set<Self>, of object: [String: JSONValue], keys: (Self) -> Set<String>) -> [String: JSONValue] {
        let dropped = Set(allCases).subtracting(parts).reduce(into: Set<String>()) { $0.formUnion(keys($1)) }
        return object.filter { !dropped.contains($0.key) }
    }

    /// What the result says about the parts it left out, and how to ask
    /// for them; nil when none was.
    static func leftOutJSON(_ parts: Set<Self>) -> [String: JSONValue]? {
        let left = allCases.filter { !parts.contains($0) }
        guard !left.isEmpty else { return nil }
        let names = left.map(\.rawValue)
        return [
            "leftOut": .array(names.map(JSONValue.string)),
            "leftOutNote": .string(String(localized: """
            Left out to keep this small: \(names.joined(separator: ", ")). Ask for them with include, e.g. \
            include: ["\(names[0])"] (or ["all"]), and eventId for one event.
            """)),
        ]
    }
}

//
//  WorkspaceSectionStatus.swift
//  Atlas
//

import Foundation

/// The line under the section's title in the toolbar (README — toolbar,
/// "Section by section"): the section's own state, then how much isn't
/// pushed yet, “32 suggestions in 6 languages · 3 not pushed”. The
/// not-pushed part is a link to Review & Push showing only this section.
struct WorkspaceSectionStatus: Equatable {
    let section: AppWorkspaceSection
    /// Suggestions waiting in the section (Analytics: new findings).
    var waiting = 0
    /// Changes and images of this section queued in Review & Push.
    var notPushed = 0
    /// Overview's own lead: the app and its version, “Lumen Journal · 1.4
    /// not submitted”.
    var lead: String?
    /// What's on in the section, after what waits: “auto-reply on”.
    var note: String?
    /// What the section read, for the lines that say more than a count.
    var facts = Facts()

    /// What a section's line needs besides its count; nil (or 0) for what
    /// isn't read yet, so the line leaves it out.
    struct Facts: Equatable {
        /// Store Page: the languages with a suggestion.
        var languages = 0
        /// Custom Product Pages: the pages, drafts included.
        var pages: Int?
        /// In-App Events: the events, and the drafts still missing an image.
        var events: Int?
        var eventsNeedingArtwork = 0
        /// Ratings & Reviews: the App Store's average, and the reviews
        /// that need a reply.
        var rating: Double?
        var withoutReply: Int?
        /// Analytics: the days the section shows.
        var days: Int?
        /// Analytics: what it's doing before the first reports (“Waiting
        /// for Apple’s first reports”), or a new app's “Since Nov 1 · 9
        /// days of data”; nil for the usual line.
        var analyticsStatus: String?

        /// A draft or rejected event: the ones whose tile says an image is
        /// missing.
        static func waitsForArtwork(_ event: InAppEvent) -> Bool {
            event.state == .draft || event.state == .rejected
        }

        /// The drafts without an event card or details image, from what
        /// was read (before the section counts what waits in Review & Push).
        static func eventsNeedingArtwork(_ events: [InAppEvent]) -> Int {
            events.count { event in
                waitsForArtwork(event) && InAppEventMedia.Kind.allCases.contains { event.media($0) == nil }
            }
        }
    }

    /// The section's state: “32 suggestions in 6 languages”, “Every
    /// caption reviewed”, “3 pages · 2 ideas”, “4.7 ★ · 4 reviews without a
    /// reply”; nil when there's nothing to say.
    var stateText: String? {
        let parts: [String] = switch section {
        case .overview: []
        case .storePage: [storePageText]
        case .screenshots: [counted(String(localized: "1 caption suggested"), String(localized: "\(waiting) captions suggested"), done: String(localized: "Every caption reviewed"))]
        case .appInformation: [counted(String(localized: "1 answer suggested", comment: "kind:done-state"), String(localized: "\(waiting) answers suggested", comment: "kind:done-state"), done: String(localized: "Every page reviewed"))]
        case .subscriptionPricing: [counted(String(localized: "1 suggestion"), String(localized: "\(waiting) suggestions"), done: String(localized: "Every price reviewed"))]
        case .productPages: productPagesParts
        case .inAppEvents: eventsParts
        case .reviews: reviewsParts
        case .analytics: analyticsParts
        case .nominations: waiting > 0 ? [counted(String(localized: "1 suggestion"), String(localized: "\(waiting) suggestions"), done: "")] : []
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// “3 not pushed”; nil when everything is pushed.
    var notPushedText: String? {
        notPushed > 0 ? String(localized: "\(notPushed) not pushed") : nil
    }

    /// Everything before the link: the lead, the section's state and its
    /// note; nil when none has anything to say.
    var leadingText: String? {
        let parts = [lead, stateText, note].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The whole line, for VoiceOver and the help tag.
    var text: String {
        let parts = [lead, stateText, note, notPushedText].compactMap(\.self)
        return parts.isEmpty ? String(localized: "Nothing waiting") : parts.joined(separator: " · ")
    }

    // MARK: - Sections

    private func counted(_ one: String, _ many: String, done: String) -> String {
        switch waiting {
        case 0: done
        case 1: one
        default: many
        }
    }

    /// “32 suggestions in 6 languages”, or “Every language reviewed”.
    private var storePageText: String {
        guard waiting > 0 else { return String(localized: "Every language reviewed") }
        let suggestions = waiting == 1 ? String(localized: "1 suggestion") : String(localized: "\(waiting) suggestions")
        switch facts.languages {
        case 0: return suggestions
        case 1: return String(localized: "\(suggestions) in 1 language", comment: "kind:other")
        default: return String(localized: "\(suggestions) in \(facts.languages) languages", comment: "kind:other")
        }
    }

    /// “3 pages · 2 ideas”.
    private var productPagesParts: [String] {
        var parts: [String] = []
        if let pages = facts.pages {
            let text = switch pages {
            case 0: String(localized: "No pages yet")
            case 1: String(localized: "1 page")
            default: String(localized: "\(pages) pages")
            }
            parts.append(text)
        }
        if waiting > 0 {
            parts.append(waiting == 1 ? String(localized: "1 idea", comment: "kind:other") : String(localized: "\(waiting) ideas", comment: "kind:other"))
        }
        return parts
    }

    /// “3 events · 1 needs artwork”, with the languages suggested after.
    private var eventsParts: [String] {
        var parts: [String] = []
        if let events = facts.events {
            let text = switch events {
            case 0: String(localized: "No events yet", comment: "kind:status")
            case 1: String(localized: "1 event", comment: "kind:status")
            default: String(localized: "\(events) events", comment: "kind:status")
            }
            parts.append(text)
        }
        switch facts.eventsNeedingArtwork {
        case 0: break
        case 1: parts.append(String(localized: "1 needs artwork", comment: "kind:status"))
        default: parts.append(String(localized: "\(facts.eventsNeedingArtwork) need artwork", comment: "kind:status"))
        }
        if waiting > 0 {
            parts.append(waiting == 1 ? String(localized: "1 language suggested") : String(localized: "\(waiting) languages suggested"))
        }
        return parts
    }

    /// “4.7 ★ · 4 reviews without a reply”.
    private var reviewsParts: [String] {
        var parts: [String] = []
        if let rating = facts.rating { parts.append(RatingsSummary.starsText(rating)) }
        if let withoutReply = facts.withoutReply {
            let text = switch withoutReply {
            case 0: String(localized: "No review waits for a reply", comment: "kind:status")
            case 1: String(localized: "1 review without a reply", comment: "kind:status")
            default: String(localized: "\(withoutReply) reviews without a reply", comment: "kind:status")
            }
            parts.append(text)
        }
        return parts
    }

    /// “Last 28 days · 2 new findings”; before the first reports what
    /// Analytics is doing (`AnalyticsAvailability.toolbarText`).
    private var analyticsParts: [String] {
        var parts: [String] = []
        if let status = facts.analyticsStatus {
            parts.append(status)
        } else if let days = facts.days {
            parts.append(String(localized: "Last \(days) days", comment: "kind:status"))
        }
        if waiting > 0 {
            parts.append(waiting == 1 ? String(localized: "1 new finding") : String(localized: "\(waiting) new findings"))
        }
        return parts
    }
}

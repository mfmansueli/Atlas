//
//  PushSchedule.swift
//  Atlas
//

import Foundation

/// Which changes of a push can go out at the same time. Up to
/// `concurrentChanges` are sent at once; each change waits for the earlier
/// ones it depends on:
/// - A plain text edit (a `PATCH` with nothing to fill in, on the Store
///   Page, App Information or an In-App Event) depends on nothing but
///   earlier changes to the same resource, so two writes never race on one.
/// - An event's card or details page waits only for earlier art of the same
///   language; art for a language the push creates also waits for the app's
///   ordered changes (that language among them).
/// - A custom product page's own screenshots wait for the app's ordered
///   changes (the page and its texts among them) and for earlier ones of
///   the same page and language; its other languages go side by side.
/// - Everything else (new languages, versions, subscriptions, retention,
///   prices, In-App Texts, merged age rating answers…) keeps the queue's
///   order within its app, as when changes went one at a time.
enum PushSchedule {
    /// Changes in flight at once: Apple counts requests per hour, not at
    /// once (the hourly budget still paces the push), and uploads side by
    /// side cut a long push to a fraction.
    static let concurrentChanges = 8

    /// Uploads Apple may be processing at once beside them: a change Apple
    /// processes gives its place to the next and only checks back.
    static let processingAtOnce = 12

    /// Whether another change can start, with `running` changes going and
    /// `waitingOnApple` of them only waiting for Apple's processing.
    static func hasRoom(running: Int, waitingOnApple: Int) -> Bool {
        running - waitingOnApple < concurrentChanges && running < concurrentChanges + processingAtOnce
    }

    /// How long a processing upload waits between checks: 2 s alone, longer
    /// the more are processing, so the checks stay within Apple's hourly
    /// budget (about one every 2 s in all).
    static func pollInterval(waitingOnApple: Int) -> Duration {
        .seconds(max(2, 2 * waitingOnApple))
    }

    /// For each change, the indices of the earlier ones it waits for.
    static func waits(for changes: [PendingChange]) -> [[Int]] {
        let kinds = changes.map(Kind.init)
        let keys = changes.map(resourceKeys)
        return changes.indices.map { index in
            changes.indices.prefix(index).filter { earlier in
                if !keys[index].isDisjoint(with: keys[earlier]) { return true }
                guard changes[earlier].appID == changes[index].appID, kinds[earlier] == .ordered else { return false }
                return kinds[index] == .ordered || kinds[index] == .artForANewLanguage || kinds[index] == .pageScreenshots
            }
        }
    }

    private enum Kind: Equatable {
        case independent
        case art
        case artForANewLanguage
        case pageScreenshots
        case ordered

        init(_ change: PendingChange) {
            let requests = change.pushRequests
            if let first = requests.first, ProductPageScreenshotsPush(first) != nil {
                self = .pageScreenshots
            } else if let first = requests.first, InAppEventArtworkPush(first) != nil {
                self = InAppEventPushOrder.waitsForANewLanguage(change) ? .artForANewLanguage : .art
            } else if change.mergeKey == nil, PushSchedule.independentSections.contains(change.section), !requests.isEmpty,
                      requests.allSatisfy({ $0.method == .patch && !PushSchedule.hasPlaceholder($0) })
            {
                self = .independent
            } else {
                self = .ordered
            }
        }
    }

    /// Sections whose plain `PATCH`es touch nothing shared: no draft
    /// version made on refusal, no group or page found once per push.
    private static let independentSections: Set<AppWorkspaceSection> = [.storePage, .appInformation, .inAppEvents]

    /// The resources a change writes: its requests' paths, or an event
    /// image's language.
    private static func resourceKeys(_ change: PendingChange) -> Set<String> {
        Set(change.pushRequests.map { request in
            InAppEventArtworkPush(request).map { "eventArtwork:\($0.localizationID)" }
                ?? ProductPageScreenshotsPush(request)?.resourceKey
                ?? request.path
        })
    }

    /// A `{…}` Atlas fills in while pushing (`{createdID}`, `{secret:…}`,
    /// `{eventLocalization:…}`…): a path segment or a whole JSON string.
    private static func hasPlaceholder(_ request: PushRequest) -> Bool {
        guard !request.path.contains("{") else { return true }
        guard let body = request.body else { return false }
        return String(bytes: body, encoding: .utf8)?.contains("\"{") == true
    }
}

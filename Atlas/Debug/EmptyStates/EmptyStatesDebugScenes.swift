//
//  EmptyStatesDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Board 74's empty states that had no DEBUG scene of their own, under the
/// canvas's ids. The others go by their sections' ids
/// (`DesignSceneAliases`): `ft-empty`, `cp-empty`, `es-ev` (`ev-empty`),
/// `es-rv` (`rv-empty`), `es-an` (`an-waiting`) and `es-rp`
/// (`review-empty`).
///
/// - `es-sh`: Lumen with no screenshot anywhere, on Preview: No
///   screenshots yet and Add Screenshots….
/// - `es-rv-done`: every review that needs a reply has one: Needs a
///   Reply's smaller empty state with Show All Reviews.
enum EmptyStatesDebugScenes {
    static let ids = ["es-sh", "es-rv-done"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "es-sh": screenshots
        case "es-rv-done": allReplied
        default: nil
        }
    }

    @MainActor
    private static var screenshots: AnyView {
        let screenshots = DebugScreenshotsServices(scenario: .noCaptures)
        screenshots.initialTab = .preview
        var storePage = DebugStorePageServices(hasEditableVersion: true)
        storePage.screenshots = screenshots
        var services = WorkspaceServices.debug
        services.storePage = storePage
        return AnyView(DebugMainScene(services: services, section: .screenshots))
    }

    @MainActor
    private static var allReplied: AnyView {
        var archive = DebugReviewsData.archive
        archive.reviews = archive.reviews.map { review in
            guard review.needsReply else { return review }
            var replied = review
            replied.reply = ReviewReply(id: "debug-reply-\(review.id)", text: "Thank you for writing.", date: DebugReviewsData.today)
            return replied
        }
        return ReviewsDebugScenes.scene(store: DebugReviewsData.store(archive: archive))
    }
}
#endif

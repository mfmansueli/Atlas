//
//  DebugReviewData+NewVersion.swift
//  Atlas
//

#if DEBUG
import Foundation

// "review-newversion": Lumen's 1.5, queued by Claude Code with its What's
// New in two languages and its App Review notes, written before App Store
// Connect has it.
extension DebugReviewData {
    static var newVersionChanges: [PendingChange] {
        let assistant = ChangeSource.assistant(client: "Claude Code")
        let appID = DebugFixtures.AppID.lumen
        let version = NewAppVersionChangeBuilder(appID: appID).change(
            for: NewAppVersion(versionString: "1.5", platform: "IOS"),
            showsPlatform: false,
            source: assistant,
            reason: "MARKETING_VERSION is 1.5."
        )
        guard let queued = QueuedAppVersion(change: version) else { return [version] }
        func text(_ id: String, title: String, old: String, new: String, path: String) -> PendingChange {
            queued.tie(PendingChange(
                id: "storePage.\(appID).version.\(queued.versionToken).\(id)",
                appID: appID,
                section: .storePage,
                group: "Store Page · Version 1.5",
                title: title,
                oldValue: old,
                newValue: new,
                source: assistant,
                requests: [PushRequest(method: .patch, path: path, body: nil)]
            ))
        }
        return [
            version,
            text("en-US.whatsNew", title: "What’s New · English (U.S.)", old: "Bug fixes.", new: "Weekly reviews, now in a widget.",
                 path: "/v1/appStoreVersionLocalizations/\(queued.localizationToken(.englishUS))"),
            text("de-DE.whatsNew", title: "What’s New · German", old: "Fehlerbehebungen.", new: "Wochenrückblicke, jetzt als Widget.",
                 path: "/v1/appStoreVersionLocalizations/\(queued.localizationToken(.german))"),
            text("appReview.notes", title: "App Review · Notes", old: "Use the demo account.", new: "Use the demo account; widgets are under Settings.",
                 path: "/v1/appStoreReviewDetails/\(queued.reviewDetailToken)"),
        ]
    }
}
#endif

//
//  ReviewPageFocus.swift
//  Atlas
//

import Foundation

/// The custom product page Push and Submit… opened Review & Push on: the
/// sheet shows that page's changes first, with the switch to the app's.
struct ReviewPageFocus: Hashable, Sendable {
    let appID: StoreApp.ID
    let pageID: String
    let name: String

    /// Whether `change` is one of this page's: its name, Visible, version,
    /// languages and screenshots, or what makes it when it's a draft.
    func owns(_ change: PendingChange) -> Bool {
        change.appID == appID && change.section == .productPages && change.groupID == pageID
    }
}

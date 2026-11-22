//
//  ReviewScope.swift
//  Atlas
//

import Foundation

/// The review sheet's "Lumen Journal · 170 | All apps · 173" switch, and
/// "Private Diary · 4" when Submit for Review… opened it on one custom
/// product page (board 54), and "Store Page · 3" when the toolbar's
/// “3 not pushed” opened it on one section (board 57).
enum ReviewScope: Hashable, Sendable {
    case thisApp
    case allApps
    /// One custom product page's changes: its id (a draft's too).
    case productPage(String)
    /// One section's changes, of the selected app; Screenshots' also has
    /// the planned images and extras.
    case section(AppWorkspaceSection)

    /// The section it shows, if it's one.
    var section: AppWorkspaceSection? {
        if case let .section(section) = self { return section }
        return nil
    }
}

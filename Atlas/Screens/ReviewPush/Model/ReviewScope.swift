//
//  ReviewScope.swift
//  Atlas
//

import Foundation

/// The review sheet's "Lumen Journal · 170 | All apps · 173" switch, and
/// "Private Diary · 4" when Push and Submit… opened it on one custom
/// product page (board 54).
enum ReviewScope: Hashable, Sendable {
    case thisApp
    case allApps
    /// One custom product page's changes: its id (a draft's too).
    case productPage(String)
}

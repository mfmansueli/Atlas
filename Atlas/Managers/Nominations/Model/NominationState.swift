//
//  NominationState.swift
//  Atlas
//

import Foundation

/// Where a nomination is: a draft (on this Mac or in App Store Connect),
/// sent to Apple's editors, or archived. Apple reports nothing after it's
/// submitted, so there's no "featured" or "in review".
enum NominationState: String, CaseIterable, Hashable, Codable, Sendable {
    case draft = "DRAFT"
    case submitted = "SUBMITTED"
    case archived = "ARCHIVED"

    /// The gallery's column.
    var groupTitle: String {
        switch self {
        case .draft: String(localized: "Drafts", comment: "kind:section-title")
        case .submitted: String(localized: "Submitted", comment: "kind:section-title")
        case .archived: String(localized: "Archived", comment: "kind:section-title")
        }
    }

    /// What the gallery's column says while it's empty.
    var emptyText: String {
        switch self {
        case .draft: String(localized: "No drafts. New Nomination… starts one.", comment: "kind:empty-state")
        case .submitted: String(localized: "Nothing submitted yet.", comment: "kind:empty-state")
        case .archived: String(localized: "Nothing archived.", comment: "kind:empty-state")
        }
    }

    /// Submitted and archived nominations can't be edited.
    /// The symbol before `emptyText` (board 70 after the SF Symbols pass).
    var emptySystemImage: String {
        switch self {
        case .draft: "doc"
        case .submitted: "paperplane"
        case .archived: "archivebox"
        }
    }

    var isEditable: Bool { self == .draft }
}

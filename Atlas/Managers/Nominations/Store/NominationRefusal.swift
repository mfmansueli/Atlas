//
//  NominationRefusal.swift
//  Atlas
//

import Foundation

/// Apple refused a nomination's push (409 or 422, or another error): it
/// stays a draft, and the page says so with Apple's own words under
/// Details. Kept until the person puts it in Review & Push again.
struct NominationRefusal: Hashable, Codable, Sendable {
    /// Which row Apple refused.
    var kind: String
    /// Apple's code and text, e.g. "ENTITY_ERROR.ATTRIBUTE.INVALID — The
    /// description must not contain URLs."
    var details: String
    var date: Date

    /// Whether Apple's text points at a link in the description, so the
    /// page offers Move Link to Materials.
    var mentionsLink: Bool {
        let text = details.lowercased()
        return text.contains("url") || text.contains("link")
    }
}

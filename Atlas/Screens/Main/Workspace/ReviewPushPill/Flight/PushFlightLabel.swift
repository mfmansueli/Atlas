//
//  PushFlightLabel.swift
//  Atlas
//

import Foundation

/// The words on the chip that flies to Review & Push (board 80): what was
/// accepted, “What's New · German” or “Brazil · R$ 9,90”, or how many
/// when several went at once (Accept All).
enum PushFlightLabel {
    /// `labels`: what joined that has a name (changes, extras); `images`:
    /// screenshots that joined. Nil when nothing did.
    static func make(labels: [String], images: Int) -> String? {
        let total = labels.count + images
        guard total > 0 else { return nil }
        if total == 1 { return labels.first ?? String(localized: "1 screenshot", comment: "kind:label") }
        if labels.isEmpty { return String(localized: "\(images) screenshots", comment: "kind:label") }
        return String(localized: "\(total) changes", comment: "kind:sheet-body")
    }

    /// A change's name: its title (“German · What's New”), with the new
    /// price for a price (“Brazil · R$ 9,90”).
    static func name(of change: PendingChange) -> String {
        guard change.deltaPercent != nil, !change.newValue.isEmpty else { return change.title }
        return "\(change.title) · \(change.newValue)"
    }

    /// An extra's name: “Header · German”, “App Preview · German”.
    static func name(of item: ExtrasReviewItem) -> String {
        let kind = switch item.content {
        case let .artwork(kind): kind.title
        case .appPreview: String(localized: "App Preview", comment: "kind:label")
        case let .artworkRemoval(place): String(localized: "Remove \(place.title)", comment: "kind:label · a live header or search image deleted")
        }
        return "\(kind) · \(item.localeName)"
    }
}

//
//  InAppEventShownTexts.swift
//  Atlas
//

import Foundation

/// The three texts an event shows in one language: its own (written or
/// waiting in Review & Push), the suggestion waiting for the person, or
/// the primary language's, which people there see until it's written.
struct InAppEventShownTexts: Hashable, Sendable {
    enum Origin: Hashable, Sendable {
        case own
        case suggestion
        case fallback
    }

    var locale: String
    var name: String
    var shortDescription: String
    var longDescription: String
    var origin: Origin
    /// The texts' own direction: the fallback's is the primary language's.
    var isRightToLeft: Bool

    /// What the App Store lays over the card (short description) or the
    /// details image (long one).
    func overlay(_ kind: InAppEventMedia.Kind, badge: String, appName: String) -> InAppEventArtworkOverlayTexts {
        InAppEventArtworkOverlayTexts(
            locale: locale, isRightToLeft: isRightToLeft, badge: badge, name: name,
            description: kind == .card ? shortDescription : longDescription, appName: appName, isFallback: origin == .fallback
        )
    }
}

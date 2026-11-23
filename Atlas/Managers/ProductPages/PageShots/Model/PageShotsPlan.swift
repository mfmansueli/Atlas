//
//  PageShotsPlan.swift
//  Atlas
//

import Foundation

/// What the assistant planned for a page's screenshots: the angle, the
/// default set's screens in the order that tells the page's story, a
/// caption for each in every language, and the languages it thinks should
/// get the page's own images.
struct PageShotsPlan: Codable, Hashable, Sendable {
    /// "Privacy first. Open with the Face ID lock, then writing, then search."
    var angle: String
    var screens: [PageShotsScreen]
    /// The languages it suggests own images for, the primary among them.
    var locales: [String]
    var reason: String
    /// Who wrote it: "Claude Code".
    var source: String
    var madeAt: Date
    /// Details and how sure, beside the reason; nil in plans saved before.
    var layers: SuggestionLayers?

    /// The languages every screen has a caption in.
    func completeLocales(among locales: [String]) -> [String] {
        locales.filter { locale in !screens.isEmpty && screens.allSatisfy { $0.caption(locale) != nil } }
    }

    /// Screens without a caption in `locale`, by place (1-based).
    func missingPlaces(in locale: String) -> [Int] {
        screens.indices.filter { screens[$0].caption(locale) == nil }.map { $0 + 1 }
    }
}

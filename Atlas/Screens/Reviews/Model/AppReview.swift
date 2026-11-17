//
//  AppReview.swift
//  Atlas
//

import Foundation

/// One App Store review, with the reply on the App Store when there is one.
struct AppReview: Identifiable, Hashable, Codable, Sendable {
    var id: String
    /// ISO alpha-2 of the storefront it was written in, e.g. "DE"; "" when
    /// Apple didn't say.
    var territory: String
    /// 1 to 5.
    var rating: Int
    var title: String
    var body: String
    var nickname: String
    var date: Date
    /// The app version it was written about ("1.3"), when Apple lists the
    /// review under one of the versions read.
    var version: String?
    /// The language it's written in ("de", "ja", "pt"), as read from its
    /// text; "" when that can't be told.
    var languageCode = ""
    /// The reply on the App Store, if any.
    var reply: ReviewReply?

    /// 1 and 2 stars: what the "1–2 Stars" filter shows.
    var isLow: Bool { rating <= 2 }

    var hasReply: Bool { reply != nil }

    /// Anything under 5 stars without a reply asks for one.
    var needsReply: Bool { reply == nil && rating < 5 }

    /// A 5-star review without a reply: one is welcome, not needed.
    var replyIsOptional: Bool { reply == nil && rating >= 5 }

    /// The storefront's English name, or its code.
    var territoryName: String {
        TerritoryCatalog.standard.territory(alpha2: territory)?.name ?? territory
    }
}

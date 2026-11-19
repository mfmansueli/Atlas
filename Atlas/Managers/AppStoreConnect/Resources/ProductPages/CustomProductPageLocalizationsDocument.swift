//
//  CustomProductPageLocalizationsDocument.swift
//  Atlas
//

import Foundation

/// A page of `GET /v1/appCustomProductPageVersions/{id}/appCustomProductPageLocalizations`
/// with its keywords and its screenshot and App Preview sets included.
/// Keywords (`appKeywords`) have no attributes: the ID is the word.
struct CustomProductPageLocalizationsDocument: Decodable, Sendable {
    struct Linkage: Decodable, Sendable {
        var type: String
        var id: String
    }

    struct ToMany: Decodable, Sendable {
        var data: [Linkage]?
    }

    struct Attributes: Decodable, Sendable {
        var locale: String
        var promotionalText: String?
    }

    struct Relationships: Decodable, Sendable {
        var searchKeywords: ToMany?
        var appScreenshotSets: ToMany?
        var appPreviewSets: ToMany?
    }

    struct Localization: Decodable, Sendable {
        var id: String
        var attributes: Attributes
        var relationships: Relationships?
    }

    struct IncludedAttributes: Decodable, Sendable {
        var screenshotDisplayType: String?
        var previewType: String?
    }

    struct Included: Decodable, Sendable {
        var type: String
        var id: String
        var attributes: IncludedAttributes?
    }

    var data: [Localization]
    var included: [Included]?
    var links: AppStoreConnectPageLinks?

    /// A localization as Atlas keeps it: the set types come from `included`.
    func localization(_ resource: Localization) -> ProductPageLocalization {
        let byID = Dictionary((included ?? []).map { ($0.id, $0) }) { first, _ in first }
        let keywords = resource.relationships?.searchKeywords?.data?.map { $0.id.removingPercentEncoding ?? $0.id } ?? []
        let screenshots = resource.relationships?.appScreenshotSets?.data?.compactMap { byID[$0.id]?.attributes?.screenshotDisplayType } ?? []
        let previews = resource.relationships?.appPreviewSets?.data?.compactMap { byID[$0.id]?.attributes?.previewType } ?? []
        return ProductPageLocalization(
            id: resource.id, locale: resource.attributes.locale, promotionalText: resource.attributes.promotionalText ?? "",
            keywords: keywords, screenshotDisplayTypes: screenshots, previewTypes: previews
        )
    }
}

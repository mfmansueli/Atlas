//
//  ProductPageStepFailure.swift
//  Atlas
//

import Foundation

/// A new custom product page whose page went through but one of its later
/// writes (a language's text or keywords, `ProductPageLocaleWrite`) failed:
/// the row says which, and that a retry goes on from there. Those writes
/// read the page again before writing, so a retry makes nothing twice and
/// there's nothing to refresh first.
struct ProductPageStepFailure: Equatable {
    var pageName: String
    /// "Keywords · German", "Promotional Text · Japanese".
    var step: String
    var appleText: String

    /// The failure of `item`'s request that didn't go, when `item` makes a
    /// page that's already in App Store Connect; nil otherwise.
    init?(_ item: PushItem, error: any Error) {
        let requests = item.change.pushRequests
        guard item.sentRequestCount > 0, item.sentRequestCount < requests.count, let first = requests.first,
              let name = ProductPageAlreadyMade.name(creating: first),
              let write = ProductPageLocaleWrite(requests[item.sentRequestCount])
        else { return nil }
        pageName = name
        step = Self.step(write.content)
        appleText = ProductPageNotConfirmed.appleText(error)
    }

    /// `status` for `item`, said as its new page's step when that's what
    /// failed. A stop (rate limit, offline) keeps its own status.
    static func status(_ status: PushItemStatus, stop: String?, error: any Error, item: PushItem) -> PushItemStatus {
        guard stop == nil, status.isFailure, let failure = ProductPageStepFailure(item, error: error) else { return status }
        return .failed(failure.text)
    }

    var text: String {
        let apple = appleText.hasSuffix(".") ? appleText : appleText + "."
        return String(localized: "“\(pageName)” is in App Store Connect, but \(step) didn’t go in: \(apple) Retry goes on from there.")
    }

    static func step(_ content: ProductPageLocaleWrite.Content) -> String {
        let field: String
        let writesKeywords = !content.addKeywords.isEmpty || !content.removeKeywords.isEmpty
        if writesKeywords, content.promotionalText != nil {
            field = String(localized: "Promotional Text and Keywords")
        } else if writesKeywords {
            field = ProductPageField.keywords.title
        } else if content.promotionalText != nil {
            field = ProductPageField.promotionalText.title
        } else if content.deepLink != nil {
            return ProductPageField.deepLink.title
        } else {
            field = String(localized: "The language")
        }
        guard let locale = content.locale else { return field }
        return "\(field) · \(ProductPageChangeBuilder.localeName(locale))"
    }
}

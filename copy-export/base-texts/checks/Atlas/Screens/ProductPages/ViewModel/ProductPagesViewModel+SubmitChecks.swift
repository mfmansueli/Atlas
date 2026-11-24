//
//  ProductPagesViewModel+SubmitChecks.swift
//  Atlas
//

import Foundation

// Submit for Review's "What goes to Apple": the version and what's on it,
// the screenshots, App Review's rules for promotional text and the deep
// link, as Atlas can check them.
extension ProductPagesViewModel {
    func submitChecks(of page: ProductPage) -> [ProductPageSubmitCheck] {
        [versionCheck(page), screenshotsCheck(page), rulesCheck(page), linkCheck(page)]
    }

    /// "Version 1 of the page" · "Promotional text in 4 languages · 11
    /// keywords · deep link https://lumen.app/lock".
    private func versionCheck(_ page: ProductPage) -> ProductPageSubmitCheck {
        let number = page.editing?.number ?? 1
        let texts = page.locales.filter { !text(of: page, locale: $0).isEmpty }.count
        var parts = [
            texts == 0
                ? String(localized: "The default page’s promotional text")
                : String(localized: "Promotional text in \(ReviewText.languages(texts))"),
            ProductPageChangeBuilder.keywordCountText(keywordCount(of: page)),
        ]
        let link = deepLink(of: page)
        parts.append(link.isEmpty ? String(localized: "no deep link") : String(localized: "deep link \(link)"))
        return ProductPageSubmitCheck(
            id: "version", title: String(localized: "Version \(number) of the page"), detail: parts.joined(separator: " · ")
        )
    }

    /// Its own screenshots in some languages (in App Store Connect, or made
    /// for it and waiting in Review & Push), or the default page's. A page
    /// with keywords and none of its own is a warning: search results show
    /// its first screenshots, so there it looks like the default page.
    private func screenshotsCheck(_ page: ProductPage) -> ProductPageSubmitCheck {
        let queued = Set(builder.screenshotChanges(pageID: page.id, pageName: page.name, in: queue.changes(for: app.id, section: .productPages))
            .compactMap { $0.requests.lazy.compactMap(ProductPageScreenshotsPush.init).first?.content.locale })
        let locales = page.locales + queued.sorted().filter { !page.locales.contains($0) }
        let own = locales.filter { queued.contains($0) || page.localization($0)?.hasOwnScreenshots == true }
        guard !own.isEmpty else {
            let title = String(localized: "The default page’s screenshots and App Previews")
            guard keywordCount(of: page) > 0 else {
                return ProductPageSubmitCheck(id: "screenshots", title: title, detail: String(localized: "In every language, on every device."))
            }
            let brief = brief(of: page).map { String(localized: " The brief asks for: \($0.screens)") } ?? ""
            return ProductPageSubmitCheck(
                id: "screenshots", title: title,
                detail: String(localized: """
                In every language, on every device. Search results show a page’s first screenshots, not its text, so for its \
                keywords it looks just like the default page. Make its own with Make Screenshots for This Page… before you submit.
                """) + brief,
                isFine: false
            )
        }
        let devices = ProductPageDevice.allCases.filter { device in
            own.contains { hasOwnScreenshots(page, locale: $0, device: device) || queuedScreenshots(of: page, locale: $0, device: device) != nil }
        }
        let names = own.map(ProductPageChangeBuilder.localeName).formatted(.list(type: .and))
        let detail = devices.isEmpty ? names : "\(names) · \(devices.map(\.title).formatted(.list(type: .and)))"
        return ProductPageSubmitCheck(
            id: "screenshots", title: String(localized: "Its own screenshots in \(ReviewText.languages(own.count))"), detail: detail
        )
    }

    /// No price, offer or other platform in any language's text.
    private func rulesCheck(_ page: ProductPage) -> ProductPageSubmitCheck {
        let written = page.locales.filter { !text(of: page, locale: $0).isEmpty }
        let problems = written.compactMap { locale -> String? in
            let issues = StoreTextGuidelineCheck.issues(in: text(of: page, locale: locale), for: ListingField.promotionalText)
            guard let first = issues.first else { return nil }
            return "\(ProductPageChangeBuilder.localeName(locale)): \(first.message)"
        }
        guard problems.isEmpty else {
            return ProductPageSubmitCheck(
                id: "rules", title: String(localized: "App Review may reject the promotional text"),
                detail: problems.joined(separator: "\n"), isFine: false
            )
        }
        let detail = written.isEmpty
            ? String(localized: "The page uses the default page’s text, already approved.")
            : String(localized: "No price, offer or other platform, in \(written.count == 1 ? String(localized: "its 1 language") : String(localized: "all \(written.count) languages")).")
        return ProductPageSubmitCheck(id: "rules", title: String(localized: "Promotional text follows App Review’s rules"), detail: detail)
    }

    /// Complete, and like the links the app's other pages use.
    private func linkCheck(_ page: ProductPage) -> ProductPageSubmitCheck {
        switch deepLinkCheck(for: page).result {
        case .empty:
            ProductPageSubmitCheck(
                id: "deepLink", title: String(localized: "No deep link"),
                detail: String(localized: "People who already have \(app.name) tap Open and land on its first screen.")
            )
        case let .fine(message):
            ProductPageSubmitCheck(id: "deepLink", title: String(localized: "The deep link opens in \(app.name)"), detail: message)
        case let .unfamiliar(message), let .incomplete(message):
            ProductPageSubmitCheck(id: "deepLink", title: String(localized: "Check the deep link"), detail: message, isFine: false)
        }
    }
}

//
//  PageShotsSource.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// What a page's screenshots are made from: the app's Screenshots document
/// (the default page's template, its screens' captures and captions),
/// read and never changed. Lays out and renders one screenshot of a page's
/// set: the screen's capture on the template's design for its place in
/// the set, with the page's caption.
@MainActor
struct PageShotsSource {
    let app: StoreApp
    let services: any ScreenshotsServices
    let document: ScreenshotsDocument
    /// The App Store ratings laurels show and the reviews a Reviews slot
    /// quotes, looked up for the page's languages (`lookingUpStore`), so
    /// a page never shows the template's sample rating.
    var ratings: StoreRatings = .unchecked
    var reviews: StoreReviews = .none

    static func load(app: StoreApp, services: any ScreenshotsServices) async throws -> PageShotsSource {
        let primary = app.primaryLocale.flatMap(StoreLocaleCatalog.locale(code:)) ?? .englishUS
        let document = try await services.loadDocument(for: app, primaryLocale: primary)
        return PageShotsSource(app: app, services: services, document: document)
    }

    /// The same source with the App Store's ratings and reviews in the
    /// countries of `locales`, as the default page's push lays them out.
    func lookingUpStore(for locales: [String]) async -> PageShotsSource {
        guard let template else { return self }
        let stores = locales.compactMap(StoreLocaleCatalog.locale(code:))
        var source = self
        let countries = template.ratingCountries(scope: document.scope, locales: stores)
        if !countries.isEmpty { source.ratings = await services.storeRatings(for: app, countries: countries) }
        if template.showsReviews {
            let primary = StoreLocaleCatalog.locale(code: primary)?.regionCode.uppercased()
            var found = await services.storeReviews(for: app, countries: Set(stores.map { $0.regionCode.uppercased() } + [primary].compactMap(\.self)))
            found.primaryCountry = primary
            source.reviews = found
        }
        return source
    }

    var primary: String { document.scope.primary }

    var template: ScreenshotTemplate? { document.template }

    /// The default set's screens.
    var slotCount: Int { document.slotCount }

    /// The devices a page's set is made for: iPhone and iPad, where the
    /// default set has captures. (Custom product pages are for iPhone and
    /// iPad.)
    var displays: [ScreenshotDisplayType] {
        [ScreenshotDisplayType.iPhone, .iPad].filter { document.captures.hasCaptures(on: $0) }
    }

    /// Why a page's set can't be made from the default page's yet; nil
    /// when it can.
    var problem: String? {
        if template == nil || slotCount == 0 {
            return String(localized: """
            \(app.name) has no screenshots made in Atlas yet. Make the default page’s in Screenshots first: a page’s set \
            uses its template and its screens.
            """)
        }
        if displays.isEmpty {
            return String(localized: "\(app.name)’s screenshots have no iPhone or iPad captures yet. Add them in Screenshots first.")
        }
        return nil
    }

    /// "Today", "Privacy".
    func slotName(_ slot: Int) -> String { document.slotName(slot) }

    /// The default page's caption of a screen in a language.
    func caption(locale: String, slot: Int) -> ScreenshotCaption? {
        document.captions.caption(locale: locale, slot: slot)
    }

    var engine: ScreenshotLayoutEngine { ScreenshotLayoutEngine(catalog: services.fonts, ratings: ratings, reviews: reviews) }

    // MARK: - Laying out

    /// The layout of the screenshot at `position` of a page's set, showing
    /// `screens[position]`'s capture with `caption`.
    func layout(
        position: Int, of screens: [PageShotsScreen], caption: PageShotsCaption?, locale: StoreLocale,
        displayType: ScreenshotDisplayType, engine: ScreenshotLayoutEngine? = nil
    ) -> ScreenshotLayout? {
        guard var template, screens.indices.contains(position) else { return nil }
        let capture = capture(of: screens[position], locale: locale.code, displayType: displayType)
        template.canvas = template.canvas.following(capture?.capture.pixelSize, on: displayType)
        return (engine ?? self.engine).layout(
            template, slot: min(position, max(0, template.slots.count - 1)), locale: locale, displayType: displayType,
            caption: caption?.screenshotCaption, captureSize: capture?.capture.pixelSize
        )
    }

    /// The screen's capture in `locale`, else the primary language's.
    func capture(of screen: PageShotsScreen, locale: String, displayType: ScreenshotDisplayType) -> ResolvedCapture? {
        document.captures.capture(locale: locale, displayType: displayType, slot: screen.slot, primary: primary)
    }

    /// Whether `caption` fits at `position` on `displayType` in `locale`.
    func fits(
        _ caption: PageShotsCaption, position: Int, of screens: [PageShotsScreen], locale: StoreLocale,
        displayType: ScreenshotDisplayType, engine: ScreenshotLayoutEngine? = nil
    ) -> Bool {
        guard let layout = layout(position: position, of: screens, caption: caption, locale: locale, displayType: displayType, engine: engine)
        else { return false }
        return layout.headline.fits && layout.subhead?.fits != false
    }

    // MARK: - Rendering

    /// The full-size PNG of the screenshot at `position`, as it's uploaded:
    /// the same render the default page's push makes. `pixelWidth` makes
    /// a smaller one for a preview.
    func render(
        position: Int, of screens: [PageShotsScreen], caption: PageShotsCaption?, locale: StoreLocale, displayType: ScreenshotDisplayType,
        pixelWidth: Int? = nil
    ) async -> (data: Data, fits: Bool)? {
        guard let template,
              let layout = layout(position: position, of: screens, caption: caption, locale: locale, displayType: displayType)
        else { return nil }
        let width = pixelWidth ?? layout.canvas.pixelSize.width
        var image: CGImage?
        if let capture = capture(of: screens[position], locale: locale.code, displayType: displayType) {
            image = await services.captureImage(capture.capture, for: app, pixelWidth: width)
        }
        // Two phones: the screen before it stands behind this one.
        var companion: CGImage?
        let templateSlot = min(position, max(0, template.slots.count - 1))
        if image != nil, let behind = template.behindSlot(position, templateSlot: templateSlot, count: screens.count),
           let file = capture(of: screens[behind], locale: locale.code, displayType: displayType)
        {
            companion = await services.captureImage(file.capture, for: app, pixelWidth: width)
        }
        let fits = layout.headline.fits && layout.subhead?.fits != false
        if let pixelWidth {
            guard let small = ScreenshotImageRenderer.image(layout: layout, capture: image, companion: companion, pixelWidth: pixelWidth),
                  let data = ScreenshotPNG.data(small) else { return nil }
            return (data, fits)
        }
        guard let data = ScreenshotImageRenderer.pngData(layout: layout, capture: image, companion: companion) else { return nil }
        return (data, fits)
    }
}

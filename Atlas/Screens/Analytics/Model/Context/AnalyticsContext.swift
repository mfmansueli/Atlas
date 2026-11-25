//
//  AnalyticsContext.swift
//  Atlas
//

import Foundation

/// What the rest of Atlas knows that explains a number: which page
/// each territory sees, how it was translated, whose screenshots it shows,
/// and how its price sits against purchasing power. Everything is optional:
/// a part that couldn't be read is simply not mentioned.
struct AnalyticsContext: Hashable, Sendable {
    var primaryLocale: StoreLocale?
    /// The languages the App Store page has.
    var pageLocales: [StoreLocale] = []
    /// Languages whose page is mostly machine-translated.
    var machineTranslated: Set<String> = []
    /// Languages with screenshots of their own; nil when not read.
    var screenshotLocales: Set<String>?
    /// Each device's languages with screenshots, from the live sets; nil
    /// when not read.
    var screenshotCoverage: ScreenshotCoverage?
    /// Each language's `appStoreVersionLocalizations` ID, which the live
    /// screenshot sets are read with.
    var versionLocalizations: [StoreLocale: String] = [:]
    /// By territory alpha-2.
    var prices: [String: TerritoryPriceContext] = [:]
    /// Retention messages live on the App Store; nil when not read.
    var liveRetentionMessages: Int?

    static let empty = AnalyticsContext()

    /// Takes what the version's live sets show: the languages with
    /// screenshots of their own, and each device's.
    mutating func setScreenshots(_ live: LiveScreenshots) {
        let coverage = ScreenshotCoverage(live: live, pageLocales: pageLocales)
        screenshotCoverage = coverage
        screenshotLocales = coverage.locales
    }

    /// The page a territory's App Store shows: its own language's when the
    /// app has one, else a page in the same language, else the primary one.
    func locale(for territory: String) -> StoreLocale? {
        let code = territory.uppercased()
        let language = Locale.Language(identifier: "und-" + code).maximalIdentifier
        let languageCode = Locale.Language(identifier: language).languageCode?.identifier
        if let exact = pageLocales.first(where: { $0.regionCode == code && $0.language.languageCode?.identifier == languageCode }) { return exact }
        if let sameRegion = pageLocales.first(where: { $0.regionCode == code }) { return sameRegion }
        if let languageCode, let sameLanguage = pageLocales.first(where: { $0.language.languageCode?.identifier == languageCode }) {
            return sameLanguage
        }
        return primaryLocale
    }

    func textState(for territory: String) -> PageTextState? {
        guard !pageLocales.isEmpty, let locale = locale(for: territory) else { return nil }
        let code = territory.uppercased()
        let language = Locale.Language(identifier: Locale.Language(identifier: "und-" + code).maximalIdentifier).languageCode?.identifier
        if locale == primaryLocale, locale.language.languageCode?.identifier != language { return .noPage }
        return machineTranslated.contains(locale.code) ? .machineTranslated : .written
    }

    /// Whether the territory's page shows its own language's screenshots;
    /// nil when not known.
    func hasOwnScreenshots(for territory: String) -> Bool? {
        guard let screenshotLocales, let locale = locale(for: territory) else { return nil }
        return screenshotLocales.contains(locale.code)
    }

    /// The territories in `territories` whose page is one of `localeCodes`;
    /// empty when the languages aren't known.
    func territories(showing localeCodes: [String], among territories: [String] = TerritoryCatalog.standard.territories.map(\.alpha2)) -> Set<String> {
        guard !localeCodes.isEmpty, !pageLocales.isEmpty else { return [] }
        let wanted = Set(localeCodes)
        return Set(territories.filter { locale(for: $0).map { wanted.contains($0.code) } ?? false })
    }
}

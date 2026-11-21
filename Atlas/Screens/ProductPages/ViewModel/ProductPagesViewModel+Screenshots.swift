//
//  ProductPagesViewModel+Screenshots.swift
//  Atlas
//

import Foundation

// The editor's Screenshots and App Previews (read-only here): a language's
// own sets when the page has them on the device, else the default page's
// in that language. A draft copying another page shows that page's.
extension ProductPagesViewModel {
    /// Where a page's own screenshots come from: itself, or for a draft
    /// copying another page, that page.
    func screenshotPage(of page: ProductPage) -> ProductPage? {
        guard let draft = draft(of: page) else { return page }
        if case let .copy(pageID, _) = draft.start { return self.page(pageID) }
        return nil
    }

    /// The page shows its own screenshots or App Previews in a language on
    /// a device.
    func hasOwnScreenshots(_ page: ProductPage, locale: String, device: ProductPageDevice) -> Bool {
        guard let source = screenshotPage(of: page), !source.isDraft, let localization = source.localization(locale) else { return false }
        return localization.screenshotDisplayTypes.contains(where: device.matches) || localization.previewTypes.contains(where: device.matchesPreview)
    }

    /// Whether it has App Previews of its own there.
    func hasOwnPreviews(_ page: ProductPage, locale: String, device: ProductPageDevice) -> Bool {
        guard let source = screenshotPage(of: page), !source.isDraft else { return false }
        return source.localization(locale)?.previewTypes.contains(where: device.matchesPreview) ?? false
    }

    /// The key of the page's own sets in a language, once it has some.
    func ownScreenshotsKey(_ page: ProductPage, locale: String) -> String? {
        guard let source = screenshotPage(of: page), !source.isDraft, let localization = source.localization(locale),
              localization.hasOwnScreenshots else { return nil }
        return "own.\(localization.id)"
    }

    /// The key of the default page's sets in a language (the primary
    /// language's when it has none).
    func defaultScreenshotsKey(_ locale: String) -> String? {
        (defaultPage.language(locale) ?? defaultPage.language(primaryLocale)).map { "default.\($0.id)" }
    }

    /// Reads what the editor and its preview show in a language: the
    /// default page's sets and the page's own. Each is read once.
    func loadScreenshots(of page: ProductPage?, locale: String) async {
        if let language = defaultPage.language(locale) ?? defaultPage.language(primaryLocale) {
            let services = services
            await loadSets("default.\(language.id)") {
                try await services.defaultScreenshots(localizationID: language.id, locale: language.locale)
            }
        }
        guard let page, let source = screenshotPage(of: page), let key = ownScreenshotsKey(page, locale: locale),
              let localization = source.localization(locale) else { return }
        let services = services
        await loadSets(key) { try await services.pageScreenshots(localizationID: localization.id, locale: locale) }
    }

    private func loadSets(_ key: String, read: () async throws -> [LiveScreenshotSet]) async {
        if let state = screenshotSets[key], state.isLoading || state.value != nil { return }
        screenshotSets[key] = .loading
        do {
            screenshotSets[key] = try await .loaded(read())
        } catch {
            screenshotSets[key] = .failed(error.localizedDescription)
        }
    }

    /// The screenshots a set shows on a device: the largest display's set
    /// with any.
    func screenshots(_ key: String?, device: ProductPageDevice) -> LoadState<[LiveScreenshot]> {
        guard let key, let state = screenshotSets[key] else { return key == nil ? .loaded([]) : .loading }
        switch state {
        case .idle, .loading: return .loading
        case let .failed(message): return .failed(message)
        case let .loaded(sets):
            return .loaded(Self.shownSet(of: sets, on: device)?.screenshots ?? [])
        }
    }

    /// The set shown for a device: its largest display's (the one a page's
    /// own screenshots go into), else the first other with screenshots.
    /// Alba's default page showed its iPhone Duo set, turned on its side,
    /// for iPhone: it came first among the APP_IPHONE sets.
    static func shownSet(of sets: [LiveScreenshotSet], on device: ProductPageDevice) -> LiveScreenshotSet? {
        let filled = sets.filter { device.matches($0.displayType.rawValue) && !$0.screenshots.isEmpty }
        return filled.first { $0.displayType == device.displayType }
            ?? filled.first { $0.displayType != .iPhoneDuo }
            ?? filled.first
    }

    /// What the page shows in a language on a device: its own, else the
    /// default page's.
    func shownScreenshots(of page: ProductPage, locale: String, device: ProductPageDevice) -> LoadState<[LiveScreenshot]> {
        if hasOwnScreenshots(page, locale: locale, device: device) {
            let own = screenshots(ownScreenshotsKey(page, locale: locale), device: device)
            if case let .loaded(shots) = own, shots.isEmpty { return screenshots(defaultScreenshotsKey(locale), device: device) }
            return own
        }
        return screenshots(defaultScreenshotsKey(locale), device: device)
    }

    /// "5 screenshots and App Previews of its own, in German.", "German
    /// shows the default page’s German screenshots."
    func screenshotsNote(of page: ProductPage, locale: String, device: ProductPageDevice) -> String {
        let name = ProductPageChangeBuilder.localeName(locale)
        guard hasOwnScreenshots(page, locale: locale, device: device) else {
            return String(localized: "\(name) shows the default page’s \(name) screenshots.")
        }
        let count = shownScreenshots(of: page, locale: locale, device: device).value?.count ?? 0
        let shots = count == 1 ? String(localized: "1 screenshot") : String(localized: "\(count) screenshots")
        if hasOwnPreviews(page, locale: locale, device: device) {
            return String(localized: "\(shots) and App Previews of its own, in \(name).")
        }
        return String(localized: "\(shots) of its own, in \(name).")
    }
}

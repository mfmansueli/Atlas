//
//  ReviewRiskFactsLoader+Texts.swift
//  Atlas
//

import Foundation

extension ReviewRiskFactsLoader {
    /// Every store text App Review reads, in every language: the version's
    /// listing (no URLs), the in-app purchases' and subscriptions' names and
    /// descriptions, App Review's notes, the In-App Events' texts, the
    /// custom product pages' promotional texts and the screenshot captions
    /// Atlas keeps. What waits in Review & Push replaces the pushed text for
    /// the listing, the in-app texts and the notes. Nil without the store
    /// page; the other places are left out when they can't be read.
    func textFacts(for app: StoreApp, shared: ReviewRiskSharedContent) async -> ReviewRiskTextFacts? {
        guard let content = shared.storePage else { return nil }
        let queue = changes.changes(for: app.id)
        var texts = Self.listingTexts(Self.queuedListing(content: content, changes: queue, appID: app.id))
        if let inApp = shared.inAppTexts {
            texts += Self.inAppTexts(inApp, content: content, changes: queue, appID: app.id)
        }
        if let information = shared.appInformation {
            texts += Self.reviewNotes(information, changes: queue, appID: app.id, primaryLocale: content.primaryLocale.code)
        }
        if let events = try? await services.inAppEvents.events(for: app) {
            texts += Self.eventTexts(events)
        }
        if let pages = try? await services.productPages.pages(for: app) {
            texts += Self.productPageTexts(pages.pages)
        }
        if let document = try? await services.screenshots.document(for: app, primaryLocale: content.primaryLocale) {
            texts += Self.captionTexts(document.captions)
        }
        let allowance = StoreTextGuidelineAllowance(
            isKidsCategory: shared.appInformation?.ageRating.isKidsCategory ?? false,
            approvedNames: [app.name]
        )
        return ReviewRiskTextFacts(texts: texts, primaryLocale: content.primaryLocale.code, allowance: allowance)
    }

    /// The version's listing with what waits in Review & Push laid on top,
    /// as the Store Page shows it.
    static func queuedListing(content: StorePageContent, changes: [PendingChange], appID: StoreApp.ID) -> StoreListing {
        let builder = ListingChangeBuilder(appID: appID, ids: content.ids, versionString: content.version.versionString)
        var listing = content.listing()
        builder.apply(changes.filter { $0.section == .storePage }, to: &listing)
        return listing
    }

    // MARK: - Places

    /// Each language's text fields that have text; URLs left out.
    static func listingTexts(_ listing: StoreListing) -> [ReviewRiskText] {
        listing.displayLocales.flatMap { locale in
            ListingField.allCases.compactMap { field -> ReviewRiskText? in
                guard !field.isURL, listing.applies(field) else { return nil }
                let draft = listing.draft(field, in: locale)
                guard !draft.local.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return ReviewRiskText(
                    place: .storeListing,
                    field: field,
                    label: "\(field.title) · \(locale.name)",
                    locale: locale.code,
                    text: draft.local,
                    isQueued: draft.isPending,
                    key: "\(ReviewRiskTextPlace.storeListing.rawValue).\(field.rawValue).\(locale.code)"
                )
            }
        }
    }

    /// The group name and each product's name and description, queued
    /// texts on top.
    static func inAppTexts(_ inApp: InAppTextsContent, content: StorePageContent, changes: [PendingChange], appID: StoreApp.ID) -> [ReviewRiskText] {
        var matrix = inApp.matrix(primaryLocale: content.primaryLocale, locales: content.locales)
        InAppTextChangeBuilder(appID: appID, content: inApp).apply(changes, to: &matrix)
        return matrix.displayLocales.flatMap { locale in
            matrix.columns.compactMap { column -> ReviewRiskText? in
                let draft = matrix.draft(column, in: locale)
                guard !draft.local.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return ReviewRiskText(
                    place: .inAppText,
                    field: nil,
                    label: "\(column.title) · \(locale.name)",
                    locale: locale.code,
                    text: draft.local,
                    isQueued: draft.isPending,
                    key: "\(ReviewRiskTextPlace.inAppText.rawValue).\(column.id).\(locale.code)",
                    inAppField: column.field,
                    owner: column.id
                )
            }
        }
    }

    /// App Review's notes for the version, queued notes on top. Not
    /// localized: they carry the primary locale.
    static func reviewNotes(_ information: AppInformationContent, changes: [PendingChange], appID: StoreApp.ID, primaryLocale: String) -> [ReviewRiskText] {
        let builder = AppInformationChangeBuilder(appID: appID, ids: information.ids, versionString: information.version?.versionString)
        let notes = builder.review(information.review, with: changes, password: { nil }).notes
        guard !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return [ReviewRiskText(
            place: .reviewNotes,
            field: nil,
            label: String(localized: "App Review notes", comment: "kind:label · where a store text is"),
            locale: primaryLocale,
            text: notes,
            isQueued: notes != information.review.notes,
            key: "\(ReviewRiskTextPlace.reviewNotes.rawValue).notes"
        )]
    }

    /// The texts of events that aren't over, in every language.
    static func eventTexts(_ events: [InAppEvent]) -> [ReviewRiskText] {
        events.filter { !$0.state.isOver }.flatMap { event in
            event.localizations.flatMap { localization in
                InAppEventField.allCases.compactMap { field -> ReviewRiskText? in
                    let text = localization.text(field)
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                    return ReviewRiskText(
                        place: .eventText,
                        field: nil,
                        label: "\(event.referenceName) · \(field.title) · \(localeName(localization.locale))",
                        locale: localization.locale,
                        text: text,
                        key: "\(ReviewRiskTextPlace.eventText.rawValue).\(event.id).\(field.rawValue).\(localization.locale)",
                        owner: event.id
                    )
                }
            }
        }
    }

    /// Each custom product page's promotional text, in the version that
    /// takes edits (else the newest).
    static func productPageTexts(_ pages: [ProductPage]) -> [ReviewRiskText] {
        pages.flatMap { page in
            (page.editing?.localizations ?? []).compactMap { localization -> ReviewRiskText? in
                guard !localization.promotionalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                let field = ListingField.promotionalText
                return ReviewRiskText(
                    place: .productPage,
                    field: nil,
                    label: "\(page.name) · \(field.title) · \(localeName(localization.locale))",
                    locale: localization.locale,
                    text: localization.promotionalText,
                    key: "\(ReviewRiskTextPlace.productPage.rawValue).\(page.id).\(field.rawValue).\(localization.locale)",
                    owner: page.id
                )
            }
        }
    }

    /// The screenshot captions Atlas keeps, each language's slots in order:
    /// kicker, headline and subhead together.
    static func captionTexts(_ book: CaptionBook) -> [ReviewRiskText] {
        book.captionsByLocale.keys.sorted().flatMap { locale in
            (book.captionsByLocale[locale] ?? []).enumerated().compactMap { slot, caption -> ReviewRiskText? in
                guard let caption, !caption.isEmpty else { return nil }
                let text = [caption.kicker, caption.headline, caption.subhead]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                let number = slot + 1
                return ReviewRiskText(
                    place: .caption,
                    field: nil,
                    label: String(localized: "Caption \(number) · \(localeName(locale))", comment: "kind:label · where a store text is"),
                    locale: locale,
                    text: text,
                    key: "\(ReviewRiskTextPlace.caption.rawValue).slot\(number).\(locale)",
                    owner: "\(number)"
                )
            }
        }
    }

    /// "German" for "de-DE"; the code when Atlas doesn't know it.
    static func localeName(_ code: String) -> String {
        StoreLocaleCatalog.locale(code: code)?.name ?? code
    }
}

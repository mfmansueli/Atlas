//
//  WorkspaceIntent.swift
//  Atlas
//

import Foundation

/// Something another part of the window asks a section to do when it opens:
/// an overview quick action, a menu command, the review sheet's "Edit…".
/// The section handles it and calls `WorkspaceNavigator.consume(_:)`.
enum WorkspaceIntent: Hashable, Sendable {
    /// Pricing: show suggestions (switching out of Keep my prices if needed).
    case reviewSuggestions
    /// Pricing: "Apply Recommended Prices…".
    case applyRecommendedPrices
    /// Pricing: the Results tab.
    case showResults
    /// Pricing: the schedule sheet for one subscription's pending prices.
    case editPriceSchedule(productID: String?)
    /// Pricing: the Prices tab as a table, tile map or histogram.
    case showPrices(PricingDisplay)
    /// App Information: one page, and App Privacy's tab, e.g. the overview's
    /// "Open Privacy URLs".
    case openAppInformationPage(AppInformationPage, privacyTab: AppPrivacyTab? = nil)
    /// Store Page: the "Translate Missing…" sheet.
    case translateMissing
    /// Store Page: Find and Replace Across Locales.
    case findAndReplace
    /// Store Page: Import Translations.
    case importTranslations
    /// Screenshots, for Review & Push's Show in Captions (the Screenshots
    /// section then opens Captions on the render).
    case showScreenshots
    /// Store Page or App Information: the fields with suggestions, from the
    /// overview's Suggestions card or the Assistant button.
    case reviewFieldSuggestions(SuggestionArea)
    /// App Information: one page's suggestions (on Accessibility, the first
    /// device with some), from Suggest Everything's Review.
    case reviewPageSuggestions(AppInformationPage)
    /// Store Page or App Information: "Ask Claude Code…", from the Assistant
    /// button's Ask for Suggestions….
    case askForSuggestions(SuggestionArea)
    /// Store Page: one language's page in the editor, from an Analytics
    /// finding (a locale code such as `de-DE`).
    case showLanguage(String)
    /// Pricing: the price matrix with one territory selected (alpha-2),
    /// from an Analytics finding.
    case showTerritoryPrice(String)
    /// Pricing: the Retention page, from an Analytics finding.
    case showRetention
    /// Reviews: Reply to All for the most mentioned group, from the
    /// Overview's Ratings & Reviews card.
    case replyToAllReviews
    /// Store Page: In-App Events, on one event when given, from the
    /// Overview's version card.
    case showInAppEvents(eventID: String?)
    /// In-App Events: one event's page, on its dates in the Details card,
    /// from the Submit sheet's Fix… on a date that has passed.
    case showInAppEventDates(eventID: String, field: InAppEventDateField)
    /// Custom Product Pages: one page in the editor, by the name Apple's
    /// reports give it, from Analytics' Product Page breakdown; the list
    /// when nil, from the Overview's card.
    case showProductPage(name: String?)
    /// Any section: focus its search field.
    case search
}

//
//  AppInformationViewModel+PrivacySuggestions.swift
//  Atlas
//

import Foundation

// App Privacy's suggestion bar, on Privacy URLs: it works on the User
// Privacy Choices URLs, one scope per language, and never on App Privacy's
// answers, which the person accepts one by one in the worksheet. The bar's
// More menu works on several scopes at once; its arrows go from language to
// language.
extension AppInformationViewModel {
    /// The scopes a page's bar works on: on Accessibility the device in
    /// view, on App Privacy every language's, the page elsewhere.
    func barScopes(on page: AppInformationPage) -> [SuggestionScope] {
        switch page {
        case .accessibility: [shownAccessibilitySuggestionFamily.map(SuggestionScope.accessibility) ?? .appInformation(page)]
        case .appPrivacy: suggestionScopes(on: .appPrivacy)
        default: [.appInformation(page)]
        }
    }

    /// The More menu's counts over several scopes, e.g. App Privacy's
    /// languages.
    func suggestionBar(for scopes: [SuggestionScope], assistant: String?) -> SuggestionBarModel {
        let all = scopes.flatMap { suggestions.all(for: app.id, scope: $0) }
        let provenanceCount = scopes.flatMap(suggestionSlots).count { provenance($0) != nil }
        var counts: [SuggestionSourceFilter: Int] = [:]
        for filter in SuggestionSourceFilter.allCases where filter != .all {
            counts[filter] = scopes.flatMap { visibleSuggestions(in: $0, filter: filter) }.count
        }
        return SuggestionBarModel(
            openCount: scopes.reduce(0) { $0 + suggestionCount(in: $1) },
            totalCount: all.count + provenanceCount,
            countsBySource: counts,
            assistantName: assistant ?? all.lazy.compactMap(\.source.assistantName).first,
            filter: suggestionFilter,
            dismissedCount: all.count(where: suggestions.isDismissed)
        )
    }

    /// "Dismiss All Here" over several scopes.
    func dismissAllSuggestions(in scopes: [SuggestionScope]) {
        suggestions.dismiss(scopes.flatMap { visibleSuggestions(in: $0) }.map(\.id))
    }

    /// "Restore n Dismissed" over several scopes.
    func restoreDismissedSuggestions(in scopes: [SuggestionScope]) {
        let dismissed = scopes.flatMap { suggestions.all(for: app.id, scope: $0) }.filter(suggestions.isDismissed)
        suggestions.restore(dismissed.map(\.id))
    }

    // MARK: - From language to language

    /// The arrows over Privacy URLs: the languages whose User Privacy
    /// Choices URL has a suggestion, and the one they went to.
    var privacySuggestionNavigation: PrivacyURLsSuggestionNavigation {
        let locales = slotValues?.privacyLocales ?? []
        return PrivacyURLsSuggestionNavigation(
            locales: locales,
            suggested: Set(locales.filter { suggestionCount(in: .appPrivacy($0)) > 0 }),
            current: privacy.focusedChoicesLocale
        )
    }

    /// Goes to `locale`'s row on Privacy URLs, where its suggestion is.
    func showPrivacySuggestion(_ locale: StoreLocale) {
        privacy.tab = .urls
        privacy.focusedChoicesLocale = locale
    }

    /// The next or previous language with a suggestion.
    func showNextPrivacySuggestion(forward: Bool = true) {
        let navigation = privacySuggestionNavigation
        guard let locale = forward ? navigation.next : navigation.previous else { return }
        showPrivacySuggestion(locale)
    }
}

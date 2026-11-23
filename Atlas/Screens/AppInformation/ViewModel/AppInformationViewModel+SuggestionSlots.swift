//
//  AppInformationViewModel+SuggestionSlots.swift
//  Atlas
//

import Foundation

// What each suggestion slot holds as shown, whether it can take a value,
// whether its value waits to be pushed, and writing one: a General or App
// Review field through `AppInformationSuggestionWriter`, an Age Rating
// answer, or an Accessibility feature in its device's declaration.
extension AppInformationViewModel {
    /// The scopes a page's suggestions are in: the page, on Accessibility
    /// one per device and the page for its URL, and on App Privacy one per
    /// language for its User Privacy Choices URL (once the URLs loaded).
    func suggestionScopes(on page: AppInformationPage) -> [SuggestionScope] {
        switch page {
        case .general, .ageRating, .appReview: [.appInformation(page)]
        case .accessibility: accessibilitySuggestionFamilies.map(SuggestionScope.accessibility) + [.appInformation(.accessibility)]
        case .appPrivacy: (slotValues?.privacyLocales ?? []).map(SuggestionScope.appPrivacy)
        // Compliance answers are the person's: never suggested, never in
        // Accept All.
        case .exportCompliance, .appCompliance: []
        }
    }

    /// The pages whose slots take suggestions, each with a suggestion bar:
    /// App Privacy's are its URLs, shown in their rows.
    static let slotPages: [AppInformationPage] = [.general, .ageRating, .accessibility, .appPrivacy, .appReview]

    /// What takes suggestions in `scope`, in the page's order.
    func suggestionSlots(in scope: SuggestionScope) -> [AppInformationSuggestionSlot] {
        switch scope {
        case .storePage:
            return []
        case let .appInformation(name):
            guard let page = AppInformationPage(rawValue: name) else { return [] }
            if page == .ageRating { return AgeRatingQuestion.allCases.map(AppInformationSuggestionSlot.ageRating) }
            return AppInformationSuggestionField.fields(on: page).map(AppInformationSuggestionSlot.field)
        case let .accessibility(code):
            guard let family = DeviceFamily(rawValue: code) else { return [] }
            return family.features.map { .accessibility(family, $0) }
        case let .appPrivacy(code):
            guard let locale = StoreLocaleCatalog.locale(code: code) else { return [] }
            return [.privacyChoicesURL(locale)]
        }
    }

    var allSuggestionSlots: [AppInformationSuggestionSlot] {
        Self.slotPages.flatMap(suggestionScopes).flatMap(suggestionSlots)
    }

    /// The devices Accessibility's suggestions can be for: every card's,
    /// and one from Other Devices once something is suggested for it.
    var accessibilitySuggestionFamilies: [DeviceFamily] {
        let shown = accessibilityCards.map(\.family)
        let suggested = otherFamilies.filter { !suggestions.all(for: app.id, scope: .accessibility($0)).isEmpty }
        return shown + suggested
    }

    /// The device Accessibility's suggestion bar shows, if the app has it.
    var shownAccessibilitySuggestionFamily: DeviceFamily? {
        let families = accessibilitySuggestionFamilies
        return families.contains(accessibilitySuggestionFamily) ? accessibilitySuggestionFamily : families.first
    }

    /// What every slot holds as shown, with what's queued on top; nil
    /// until App Information has loaded.
    var slotValues: AppInformationSlotValues? {
        content.map {
            AppInformationSlotValues(content: $0, accessibility: accessibility.value, builder: builder, changes: changes, privacyURLs: privacy.urls.value)
        }
    }

    /// Its value as shown, as stored: a category by id, an answer by raw
    /// value, a feature as `yes` or `no`; "" when a question or feature
    /// hasn't been answered.
    func suggestionValue(_ slot: AppInformationSuggestionSlot) -> String {
        slotValues?.value(slot) ?? ""
    }

    func canSuggest(_ slot: AppInformationSuggestionSlot) -> Bool {
        slotValues?.canSuggest(slot) ?? false
    }

    /// Its value differs from App Store Connect's: a queued change.
    func isPending(_ slot: AppInformationSuggestionSlot) -> Bool {
        slotValues?.isPending(slot) ?? false
    }

    /// Queues `value` tagged with `source`, replacing whatever was queued
    /// for it, so a value that changes hands (yours ↔ an assistant's)
    /// doesn't become a conflict. "" takes a question or feature back to
    /// unanswered. Returns the change's id with what was queued there
    /// before; nil when it can't take the value.
    func write(
        _ slot: AppInformationSuggestionSlot,
        _ value: String,
        source: ChangeSource
    ) -> (id: PendingChange.ID, previous: PendingChange?)? {
        guard let (change, id) = slotValues?.change(slot, to: value, source: source) else { return nil }
        let previous = queue.change(id: id)
        queue.discard(id: id)
        apply(change, id: id)
        return (id, previous)
    }

    /// The values suggestions compare against. App Review's password isn't
    /// one of their fields, so the Keychain isn't read for it.
    var suggestionValues: (general: GeneralValues?, review: AppReviewValues?) {
        guard let content else { return (nil, nil) }
        let builder = builder
        let changes = changes
        return (builder.general(content.general, with: changes), builder.review(content.review, with: changes) { nil })
    }
}

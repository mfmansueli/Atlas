//
//  AppInformationSuggestionWriter.swift
//  Atlas
//

import Foundation

/// Turns a value for one `AppInformationSuggestionField` into the change
/// that queues it, as the page's own edits do but tagged with who
/// suggested it. Accepting a suggestion on the page and `suggest_fields`
/// with `apply` both write through it.
enum AppInformationSuggestionWriter {
    /// What a change is built from: App Store Connect's content, the values
    /// shown (with queued changes on top), and the builder for the version.
    struct Values {
        var content: AppInformationContent
        var general: GeneralValues
        var review: AppReviewValues
        var builder: AppInformationChangeBuilder
    }

    /// The change for `field` set to `value` (as stored: a category,
    /// release option or content rights answer by id) and the id it's
    /// queued under. The change is nil when the field is back at App Store
    /// Connect's value; the whole result is nil when the field can't take
    /// it (the version is locked, or "On a date" without a date). A Yes to
    /// third-party content waits for the person's "I have the rights to use
    /// it", as on the page, unless App Store Connect or the person said so
    /// already.
    static func change(
        _ field: AppInformationSuggestionField,
        to value: String,
        in values: Values,
        source: ChangeSource
    ) -> (change: PendingChange?, id: String)? {
        typealias Key = AppInformationChangeBuilder.GeneralKey
        let (content, general, builder) = (values.content, values.general, values.builder)
        if field.isVersionLevel, !content.isVersionEditable { return nil }
        switch field {
        case .copyright:
            return (builder.copyrightChange(from: content.general.copyright, to: value, source: source), builder.versionChangeID(.general, Key.copyright))
        case .primaryCategory, .secondaryCategory:
            let key = field == .primaryCategory ? Key.primaryCategory : Key.secondaryCategory
            let old = field == .primaryCategory ? content.general.primaryCategory : content.general.secondaryCategory
            return (builder.categoryChange(key, from: old, to: value.isEmpty ? nil : value, source: source), builder.changeID(.general, key))
        case .gamesSubcategories:
            return subcategoriesChange(to: value, in: values, source: source)
        case .contentRights:
            return contentRightsChange(to: value, in: values, source: source)
        case .release:
            guard let option = ReleaseOption(rawValue: value) else { return nil }
            let date = general.earliestReleaseDate
            if option == .scheduled, date == nil { return nil }
            let old = (content.general.release, content.general.earliestReleaseDate)
            return (builder.releaseChange(from: old, to: (option, date), source: source), builder.versionChangeID(.general, Key.release))
        case .accessibilityURL:
            // The app's, read with Accessibility: `AppInformationSlotValues` writes it.
            return nil
        case .contactFirstName, .contactLastName, .contactPhone, .contactEmail, .demoAccountRequired, .demoAccountName, .notes:
            return reviewChange(field, to: value, in: values, source: source)
        }
    }

    /// Games subcategories: only for a game, as on the page.
    private static func subcategoriesChange(to value: String, in values: Values, source: ChangeSource) -> (change: PendingChange?, id: String)? {
        guard values.general.isGame else { return nil }
        let ids = AppInformationSuggestionField.subcategoryIDs(value)
        let builder = values.builder
        return (
            builder.gamesSubcategoriesChange(from: values.content.general.gamesSubcategories, to: ids, source: source),
            builder.changeID(.general, AppInformationChangeBuilder.GeneralKey.gamesSubcategories)
        )
    }

    /// An App Review field: its own change, or the new review details'
    /// when the version has none yet. Sign-in required is a switch.
    private static func reviewChange(
        _ field: AppInformationSuggestionField,
        to value: String,
        in values: Values,
        source: ChangeSource
    ) -> (change: PendingChange?, id: String)? {
        guard let reviewField = field.reviewField else { return nil }
        let (content, builder) = (values.content, values.builder)
        var edited = values.review
        if reviewField == .signInRequired {
            edited.signInRequired = value == AppInformationSuggestionField.yesAnswer
        } else {
            edited.setText(value, for: reviewField)
        }
        if content.ids.reviewDetailID == nil {
            return (builder.newReviewDetailChange(edited, source: source), builder.newReviewDetailChangeID)
        }
        return (builder.reviewFieldChange(reviewField, from: content.review, to: edited, source: source), builder.reviewChangeID(reviewField))
    }

    /// Yes or No to third-party content, as the page's picker: a Yes is
    /// confirmed when App Store Connect or the person already said Yes.
    private static func contentRightsChange(to value: String, in values: Values, source: ChangeSource) -> (change: PendingChange?, id: String)? {
        guard let rights = ContentRights(rawValue: value) else { return nil }
        let old = values.content.general.contentRights
        let confirmed = rights == .usesThirdPartyContent && (old == rights || values.general.rightsConfirmed)
        let change = values.builder.contentRightsChange(from: old, to: rights, rightsConfirmed: confirmed, source: source)
        return (change, values.builder.changeID(.general, AppInformationChangeBuilder.GeneralKey.contentRights))
    }
}

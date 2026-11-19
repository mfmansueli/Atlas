//
//  InAppEventsViewModel+ShownTexts.swift
//  Atlas
//

import Foundation

/// What an event says in a language, for its card in the gallery, the
/// preview and the full-size viewer: its own texts, else the suggestion
/// waiting, else the primary language's.
extension InAppEventsViewModel {
    func shownTexts(of event: InAppEvent, locale: String) -> InAppEventShownTexts {
        let own = Dictionary(uniqueKeysWithValues: InAppEventField.allCases.map { ($0, text($0, of: event, locale: locale)) })
        let isRTL = StoreLocaleCatalog.locale(code: locale)?.isRTL ?? false
        let complete = own.values.allSatisfy { !$0.isEmpty }
        if complete {
            return InAppEventShownTexts(
                locale: locale, name: own[.name] ?? "", shortDescription: own[.shortDescription] ?? "",
                longDescription: own[.longDescription] ?? "", origin: .own, isRightToLeft: isRTL
            )
        }
        if event.state.isEditable, languages(of: event).first(where: { $0.code == locale })?.state == .suggested,
           let suggestion = store.suggestion(for: app.id, eventID: event.id, locale: locale)
        {
            return InAppEventShownTexts(
                locale: locale, name: suggestion.text(.name), shortDescription: suggestion.text(.shortDescription),
                longDescription: suggestion.text(.longDescription), origin: .suggestion, isRightToLeft: isRTL
            )
        }
        let primary = event.primaryLocale ?? event.localizations.first?.locale ?? locale
        let fallback = { (field: InAppEventField) in
            let value = own[field] ?? ""
            return value.isEmpty ? self.text(field, of: event, locale: primary) : value
        }
        let hasOwn = own.values.contains { !$0.isEmpty }
        return InAppEventShownTexts(
            locale: locale, name: fallback(.name).isEmpty ? event.referenceName : fallback(.name),
            shortDescription: fallback(.shortDescription), longDescription: fallback(.longDescription),
            origin: hasOwn || primary == locale ? .own : .fallback,
            isRightToLeft: hasOwn ? isRTL : StoreLocaleCatalog.locale(code: primary)?.isRTL ?? false
        )
    }

    /// The App Store's text over `kind` in `locale`.
    func overlayTexts(_ kind: InAppEventMedia.Kind, of event: InAppEvent, locale: String) -> InAppEventArtworkOverlayTexts {
        shownTexts(of: event, locale: locale).overlay(kind, badge: event.badge?.title ?? "", appName: app.name)
    }
}

//
//  WhatsNewRow.swift
//  Atlas
//

import Foundation

/// One language's What's New in the Submit sheet.
struct WhatsNewRow: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable {
        /// In App Store Connect.
        case written
        /// Accepted or edited here and not pushed yet.
        case notPushed
        /// Missing, with a suggestion to accept.
        case suggested(FieldSuggestion)
        case missing
    }

    var locale: StoreLocale
    /// The text that would go to App Review; empty when missing.
    var text: String
    var state: State

    var id: String { locale.code }

    /// Nothing to send for this language yet.
    var isMissing: Bool {
        switch state {
        case .written, .notPushed: false
        case .suggested, .missing: true
        }
    }

    var statusTitle: String {
        switch state {
        case .written: String(localized: "Written")
        case .notPushed: String(localized: "Accepted")
        case .suggested: String(localized: "Suggested")
        case .missing: String(localized: "Missing")
        }
    }

    /// One row per language of the version, the primary first; empty for a
    /// first version, which has no What's New. A value waiting in Review &
    /// Push counts, else App Store Connect's, else a suggestion.
    @MainActor
    static func rows(for content: StorePageContent?, appID: StoreApp.ID, queue: ChangeQueue, suggestions: FieldSuggestionStore) -> [WhatsNewRow] {
        guard let content, !content.version.listingVersion.isFirstVersion else { return [] }
        let builder = ListingChangeBuilder(appID: appID, ids: content.ids, versionString: content.version.versionString)
        let ordered = [content.primaryLocale] + content.locales.filter { $0 != content.primaryLocale }
        return ordered.filter(content.locales.contains).map { locale in
            let remote = content.texts[locale]?[.whatsNew] ?? ""
            let queued = queue.change(id: builder.changeID(for: ListingFieldKey(locale, .whatsNew)))?.newValue
            if let queued, !queued.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return WhatsNewRow(locale: locale, text: queued, state: .notPushed)
            }
            if queued == nil, !remote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return WhatsNewRow(locale: locale, text: remote, state: .written)
            }
            if let suggestion = suggestions.shown(for: .storePage(locale, .whatsNew), appID: appID, currentValue: queued ?? remote) {
                return WhatsNewRow(locale: locale, text: "", state: .suggested(suggestion))
            }
            return WhatsNewRow(locale: locale, text: "", state: .missing)
        }
    }
}

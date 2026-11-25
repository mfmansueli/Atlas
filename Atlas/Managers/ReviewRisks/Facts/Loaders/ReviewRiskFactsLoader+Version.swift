//
//  ReviewRiskFactsLoader+Version.swift
//  Atlas
//

import Foundation

extension ReviewRiskFactsLoader {
    /// The version the store page opens on (the one being prepared, else
    /// the live one) and its What's New in every language, with what waits
    /// in Review & Push on top. Nil without the store page.
    func versionFacts(for app: StoreApp, shared: ReviewRiskSharedContent) async -> ReviewRiskVersionFacts? {
        guard let content = shared.storePage else { return nil }
        return Self.versionFacts(content: content, changes: changes.changes(for: app.id), appID: app.id)
    }

    static func versionFacts(content: StorePageContent, changes: [PendingChange], appID: StoreApp.ID) -> ReviewRiskVersionFacts {
        let version = content.version
        let listing = queuedListing(content: content, changes: changes, appID: appID)
        var whatsNew: [String: String] = [:]
        var queued: Set<String> = []
        if listing.applies(.whatsNew) {
            for locale in listing.displayLocales {
                let draft = listing.draft(.whatsNew, in: locale)
                whatsNew[locale.code] = draft.local
                if draft.isPending { queued.insert(locale.code) }
            }
        }
        return ReviewRiskVersionFacts(
            versionID: version.id,
            versionString: version.versionString,
            state: version.state.rawValue,
            isFirstVersion: version.listingVersion.isFirstVersion,
            isEditable: version.isEditable,
            primaryLocale: content.primaryLocale.code,
            whatsNew: whatsNew,
            queuedWhatsNew: queued
        )
    }
}

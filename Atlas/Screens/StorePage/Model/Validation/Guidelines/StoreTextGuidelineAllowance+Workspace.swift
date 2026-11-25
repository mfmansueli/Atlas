//
//  StoreTextGuidelineAllowance+Workspace.swift
//  Atlas
//

import Foundation

extension StoreTextGuidelineAllowance {
    /// What `app` may say in an assistant's store text: its approved names
    /// (the app's name and each language's name in App Store Connect), and
    /// whether it has a Kids age band. The age rating is read only when
    /// `readsAgeRating` (a proposal says "For Kids") and `ageRating` isn't
    /// known already; one that can't be read allows nothing.
    @MainActor
    static func load(
        for app: StoreApp,
        listing: StoreListing?,
        readsAgeRating: Bool,
        ageRating: AgeRatingValues? = nil,
        services: WorkspaceServices
    ) async -> StoreTextGuidelineAllowance {
        let names = [app.name] + (listing.map { listing in listing.displayLocales.map { listing.draft(.name, in: $0).remote } } ?? [])
        var isKids = ageRating?.isKidsCategory ?? false
        if readsAgeRating, ageRating == nil {
            isKids = await (try? services.appInformation.content(for: app, versionID: nil))?.ageRating.isKidsCategory ?? false
        }
        var unique: [String] = []
        for name in names where !unique.contains(name) { unique.append(name) }
        return StoreTextGuidelineAllowance(isKidsCategory: isKids, approvedNames: unique)
    }

    /// Whether any of `texts` says "For Kids" in a way the check refuses,
    /// so the age rating is worth reading.
    static func needsAgeRating(_ texts: [(String, ListingField)]) -> Bool {
        texts.contains { text, field in
            StoreTextGuidelineKind.kidsTerms.applies(to: field) && !StoreTextGuidelineCheck.issues(in: text, kinds: [.kidsTerms]).isEmpty
        }
    }
}

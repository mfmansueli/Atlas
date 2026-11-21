//
//  QueuedAppVersion+Content.swift
//  Atlas
//

import Foundation

// The Store Page and App Information of a new version that waits in
// Review & Push: the version before it's, with its own placeholder IDs, so
// what's written for it is queued for it. App Store Connect copies the
// version before's texts into a new version, and makes a new app info with
// it (name, subtitle, privacy URLs, categories, age rating) unless one is
// being prepared already; App Review details it may not.
extension QueuedAppVersion {
    func storePageContent(from base: StorePageContent) -> StorePageContent {
        var content = base
        content.version = storePageVersion
        content.versions = [storePageVersion] + base.versions
        content.ids.versionID = versionToken
        content.ids.versionLocalizations = Dictionary(
            uniqueKeysWithValues: base.ids.versionLocalizations.keys.map { ($0, localizationToken($0)) }
        )
        content.ids.appInfoID = appInfoToken
        content.ids.appInfoLocalizations = Dictionary(
            uniqueKeysWithValues: base.ids.appInfoLocalizations.keys.map { ($0, appInfoLocalizationToken($0)) }
        )
        return content
    }

    func appInformationContent(from base: AppInformationContent) -> AppInformationContent {
        var content = base
        content.version = storePageVersion
        content.versions = [storePageVersion] + base.versions
        content.ids.versionID = versionToken
        content.ids.reviewDetailID = reviewDetailToken
        content.ids.appInfoID = appInfoToken
        if base.ids.ageRatingDeclarationID != nil { content.ids.ageRatingDeclarationID = ageRatingToken }
        return content
    }

    /// The version a new one starts from: the newest on its platform, nil
    /// when it's the platform's first (then the one shown).
    func baseVersionID(among versions: [StorePageVersion]) -> StorePageVersion.ID? {
        StorePageVersion.pickerVersions(from: versions).first { $0.platform == platform }?.id
    }
}

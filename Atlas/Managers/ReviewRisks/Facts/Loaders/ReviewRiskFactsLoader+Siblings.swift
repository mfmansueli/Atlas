//
//  ReviewRiskFactsLoader+Siblings.swift
//  Atlas
//

import Foundation

extension ReviewRiskFactsLoader {
    /// The account's other apps' subtitles and descriptions, for 4.3: at
    /// most `siblingLimit` apps, each read on its own; an app that can't be
    /// read is skipped. Nil when the app list can't be read.
    func siblingApps(for app: StoreApp) async -> [ReviewRiskSiblingApp]? {
        guard let all = try? await apps() else { return nil }
        var siblings: [ReviewRiskSiblingApp] = []
        for other in all.filter({ $0.id != app.id }).prefix(Self.siblingLimit) {
            guard let content = try? await services.storePage.content(for: other, versionID: nil) else { continue }
            siblings.append(Self.sibling(other, content: content))
        }
        return siblings
    }

    /// The most other apps read for 4.3.
    static let siblingLimit = 12

    static func sibling(_ app: StoreApp, content: StorePageContent) -> ReviewRiskSiblingApp {
        var subtitles: [String: String] = [:]
        var descriptions: [String: String] = [:]
        for locale in content.locales {
            let texts = content.texts[locale] ?? [:]
            if let subtitle = texts[.subtitle], !subtitle.isEmpty { subtitles[locale.code] = subtitle }
            if let description = texts[.description], !description.isEmpty { descriptions[locale.code] = description }
        }
        return ReviewRiskSiblingApp(
            appID: app.id,
            name: app.name,
            primaryLocale: content.primaryLocale.code,
            subtitles: subtitles,
            descriptions: descriptions
        )
    }
}

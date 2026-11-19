//
//  LiveProductPagesServices.swift
//  Atlas
//

import Foundation

/// Reads custom product pages from App Store Connect: the pages and their
/// versions, the languages of the version being edited and of the approved
/// one, and the default page (the version a new page starts from, and the
/// approved version's keywords, the only words a page can choose).
@MainActor
struct LiveProductPagesServices: ProductPagesServices {
    let client: AppStoreConnectClient

    private static let liveStates: Set<String> = ["READY_FOR_DISTRIBUTION", "READY_FOR_SALE"]
    private static let doneStates: Set<String> = liveStates.union(["REPLACED_WITH_NEW_VERSION", "REMOVED_FROM_SALE", "DEVELOPER_REMOVED_FROM_SALE"])

    func pages(for app: StoreApp) async throws -> ProductPagesSnapshot {
        async let pagesRead = client.customProductPages(appID: app.id)
        async let defaultRead = defaultPage(for: app)
        var pages = try await pagesRead
        let wanted = pages.flatMap { page in Set([page.editing?.id, page.approved?.id].compactMap(\.self)) }
        let localizations = try await Self.localizations(versionIDs: wanted, client: client)
        for page in pages.indices {
            for version in pages[page].versions.indices {
                pages[page].versions[version].localizations = localizations[pages[page].versions[version].id] ?? []
            }
        }
        return try await ProductPagesSnapshot(pages: pages.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }, defaultPage: defaultRead)
    }

    func pageScreenshots(localizationID: String, locale: String) async throws -> [LiveScreenshotSet] {
        try await client.customProductPageScreenshotSets(localizationID: localizationID, locale: locale)
    }

    func defaultScreenshots(localizationID: String, locale: String) async throws -> [LiveScreenshotSet] {
        try await client.liveScreenshotSets(localizationID: localizationID, locale: locale)
    }

    func submit(versionID: String, of app: StoreApp) async throws {
        try await client.submitCustomProductPageVersion(versionID, appID: app.id, platform: "IOS")
    }

    // MARK: - Reading

    private static func localizations(versionIDs: [String], client: AppStoreConnectClient) async throws -> [String: [ProductPageLocalization]] {
        try await withThrowingTaskGroup(of: (String, [ProductPageLocalization]).self) { group in
            var found: [String: [ProductPageLocalization]] = [:]
            var pending = versionIDs[...]
            // A few at a time, to stay inside the hourly request limit's pace.
            for _ in 0..<4 {
                guard let id = pending.popFirst() else { break }
                group.addTask { try await (id, client.customProductPageLocalizations(versionID: id)) }
            }
            while let (id, localizations) = try await group.next() {
                found[id] = localizations
                if let next = pending.popFirst() {
                    group.addTask { try await (next, client.customProductPageLocalizations(versionID: next)) }
                }
            }
            return found
        }
    }

    /// The version a new page starts from (the one being prepared, else
    /// the live one) with its promotional texts, and the live version's
    /// keywords in each language.
    private func defaultPage(for app: StoreApp) async throws -> ProductPageDefault {
        let versions = try await client.appStoreVersions(appID: app.id)
            .filter { ($0.attributes.platform ?? "IOS") == "IOS" }
            .sorted { ($0.attributes.createdDate ?? "") > ($1.attributes.createdDate ?? "") }
        let live = versions.first { Self.liveStates.contains($0.attributes.state ?? "") }
        let preparing = versions.first { !Self.doneStates.contains($0.attributes.state ?? "") }
        guard let template = preparing ?? live else { return ProductPageDefault() }
        let templateTexts = try await client.appStoreVersionLocalizations(versionID: template.id)
        let liveTexts = if let live, live.id != template.id { try await client.appStoreVersionLocalizations(versionID: live.id) } else { templateTexts }
        let keywords = Dictionary(liveTexts.map { ($0.attributes.locale, ProductPageChangeBuilder.keywords(in: $0.attributes.keywords ?? "")) }) { first, _ in first }
        let languages = templateTexts.map { localization in
            ProductPageDefaultLanguage(
                id: localization.id, locale: localization.attributes.locale,
                promotionalText: localization.attributes.promotionalText ?? "",
                approvedKeywords: live == nil ? [] : keywords[localization.attributes.locale] ?? []
            )
        }
        return ProductPageDefault(
            versionID: template.id, versionString: template.attributes.versionString,
            approvedVersionString: live?.attributes.versionString, languages: languages
        )
    }
}

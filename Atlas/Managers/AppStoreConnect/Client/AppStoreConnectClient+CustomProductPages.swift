//
//  AppStoreConnectClient+CustomProductPages.swift
//  Atlas
//

import Foundation

extension AppStoreConnectClient {
    /// The app's custom product pages with their versions, languages not
    /// read yet (`GET /v1/apps/{id}/appCustomProductPages`).
    func customProductPages(appID: String) async throws -> [ProductPage] {
        var pages: [ProductPage] = []
        var next: URL? = url("/v1/apps/\(appID)/appCustomProductPages", query: [
            URLQueryItem(name: "include", value: "appCustomProductPageVersions"),
            URLQueryItem(name: "fields[appCustomProductPages]", value: "name,url,visible,appCustomProductPageVersions"),
            URLQueryItem(name: "fields[appCustomProductPageVersions]", value: "version,state,deepLink"),
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(name: "limit[appCustomProductPageVersions]", value: "50"),
        ])
        while let pageURL = next {
            let document: CustomProductPagesDocument = try await get(pageURL)
            let versions = document.versions
            for page in document.data {
                let pageVersions: [ProductPageVersion] = page.versionIDs.compactMap { id in
                    guard let attributes = versions[id]?.attributes,
                          let state = attributes.state.flatMap(ProductPageState.init(rawValue:)) else { return nil }
                    return ProductPageVersion(
                        id: id, number: Int(attributes.version ?? "") ?? 1, state: state, deepLink: attributes.deepLink ?? ""
                    )
                }
                pages.append(ProductPage(
                    id: page.id, name: page.attributes?.name ?? "", url: page.attributes?.url.flatMap(URL.init(string:)),
                    isVisible: page.attributes?.visible ?? false, versions: pageVersions
                ))
            }
            next = document.links?.next
        }
        return pages
    }

    /// A page version's languages with their keywords and the types of
    /// their own screenshot and App Preview sets.
    func customProductPageLocalizations(versionID: String) async throws -> [ProductPageLocalization] {
        var localizations: [ProductPageLocalization] = []
        var next: URL? = url("/v1/appCustomProductPageVersions/\(versionID)/appCustomProductPageLocalizations", query: [
            URLQueryItem(name: "include", value: "searchKeywords,appScreenshotSets,appPreviewSets"),
            URLQueryItem(name: "fields[appCustomProductPageLocalizations]", value: "locale,promotionalText,searchKeywords,appScreenshotSets,appPreviewSets"),
            URLQueryItem(name: "fields[appScreenshotSets]", value: "screenshotDisplayType"),
            URLQueryItem(name: "fields[appPreviewSets]", value: "previewType"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "limit[searchKeywords]", value: "50"),
            URLQueryItem(name: "limit[appScreenshotSets]", value: "50"),
            URLQueryItem(name: "limit[appPreviewSets]", value: "50"),
        ])
        while let pageURL = next {
            let document: CustomProductPageLocalizationsDocument = try await get(pageURL)
            localizations += document.data.map(document.localization)
            next = document.links?.next
        }
        return localizations
    }

    /// A page language's own screenshot sets.
    func customProductPageScreenshotSets(localizationID: String, locale: String) async throws -> [LiveScreenshotSet] {
        try await liveScreenshotSets(path: "/v1/appCustomProductPageLocalizations/\(localizationID)/appScreenshotSets", locale: locale)
    }

    /// Sends a page's version to App Review by itself: a new review
    /// submission with the version as its only item, then submitted.
    func submitCustomProductPageVersion(_ versionID: String, appID: String, platform: String?) async throws {
        let submissionID = try await createReviewSubmission(appID: appID, platform: platform)
        try await addReviewSubmissionItem(
            submissionID: submissionID, relationship: "appCustomProductPageVersion", type: "appCustomProductPageVersions", id: versionID
        )
        try await updateReviewSubmission(id: submissionID, attribute: "submitted")
    }

    /// Takes a page's version back from App Review while it waits: finds
    /// the waiting submission it went in and cancels it, when the version
    /// is all that submission holds (`PATCH /v1/reviewSubmissions/{id}`,
    /// `canceled`). A submission with more in it stays, so nothing else is
    /// taken back with the page.
    func cancelCustomProductPageSubmission(versionID: String, appID: String, platform: String?) async throws {
        let waiting = try await openReviewSubmissions(appID: appID, platform: platform)
            .filter { $0.attributes.state == "WAITING_FOR_REVIEW" }
        for submission in waiting {
            let items: AppStoreConnectLinkedPage<ReviewSubmissionItemAttributes> = try await get(url(
                "/v1/reviewSubmissions/\(submission.id)/items", query: [
                    URLQueryItem(name: "fields[reviewSubmissionItems]", value: "state,appCustomProductPageVersion"),
                    URLQueryItem(name: "limit", value: "50"),
                ]
            ))
            let pageVersions = items.data.map { $0.relationshipID("appCustomProductPageVersion") }
            guard pageVersions.contains(versionID) else { continue }
            guard pageVersions.allSatisfy({ $0 == versionID }) else {
                throw ProductPageSubmissionError.sharedSubmission
            }
            try await updateReviewSubmission(id: submission.id, attribute: "canceled")
            return
        }
        throw ProductPageSubmissionError.notWaiting
    }
}

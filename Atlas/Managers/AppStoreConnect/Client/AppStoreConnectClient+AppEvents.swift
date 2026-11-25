//
//  AppStoreConnectClient+AppEvents.swift
//  Atlas
//

import Foundation

/// In-App Events: the app's events with their texts in every language,
/// and each event's images and video (with the file's name and size as it
/// was uploaded, and Apple's processing). Reads only; changes are built by
/// `InAppEventChangeBuilder` and sent by Review & Push.
extension AppStoreConnectClient {
    /// Every event of the app with its localizations
    /// (`GET /v1/apps/{id}/appEvents?include=localizations`).
    func appEvents(appID: String) async throws -> [AppEventsDocument] {
        var pages: [AppEventsDocument] = []
        var next: URL? = url("/v1/apps/\(appID)/appEvents", query: [
            URLQueryItem(name: "include", value: "localizations"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "limit[localizations]", value: "50"),
            URLQueryItem(name: "fields[appEventLocalizations]", value: "locale,name,shortDescription,longDescription"),
        ])
        while let pageURL = next {
            let page: AppEventsDocument = try await get(pageURL)
            pages.append(page)
            next = page.links?.next
        }
        return pages
    }

    /// The images of one language of an event
    /// (`GET /v1/appEventLocalizations/{id}/appEventScreenshots`).
    func appEventScreenshots(localizationID: String) async throws -> [AppStoreConnectResource<AppEventMediaAttributes>] {
        try await allPages(of: "/v1/appEventLocalizations/\(localizationID)/appEventScreenshots", query: [
            URLQueryItem(name: "fields[appEventScreenshots]", value: "appEventAssetType,imageAsset,fileName,fileSize,assetDeliveryState"),
            URLQueryItem(name: "limit", value: "20"),
        ])
    }

    /// The video clips of one language of an event, with where each
    /// streams from (`GET /v1/appEventLocalizations/{id}/appEventVideoClips`).
    func appEventVideoClips(localizationID: String) async throws -> [AppStoreConnectResource<AppEventMediaAttributes>] {
        try await allPages(of: "/v1/appEventLocalizations/\(localizationID)/appEventVideoClips", query: [
            URLQueryItem(
                name: "fields[appEventVideoClips]",
                value: "appEventAssetType,previewFrameImage,previewImage,fileName,fileSize,previewFrameTimeCode,videoDeliveryState,videoUrl"
            ),
            URLQueryItem(name: "limit", value: "20"),
        ])
    }
}

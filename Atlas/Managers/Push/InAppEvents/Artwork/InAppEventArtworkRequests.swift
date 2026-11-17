//
//  InAppEventArtworkRequests.swift
//  Atlas
//

import Foundation

/// The App Store Connect requests an event card or details page push
/// sends (API 4.6): reserve an `appEventScreenshots` (image) or
/// `appEventVideoClips` (video) on the event's localization with its asset
/// type, upload its parts, commit it with `uploaded`, check its delivery
/// state, and delete what that asset type had before.
enum InAppEventArtworkRequests {
    static func type(isVideo: Bool) -> String {
        isVideo ? "appEventVideoClips" : "appEventScreenshots"
    }

    static func collectionPath(isVideo: Bool) -> String {
        "/v1/\(type(isVideo: isVideo))"
    }

    /// `POST /v1/appEventScreenshots` or `/v1/appEventVideoClips`: reserves
    /// an upload of `fileSize` bytes. A video can name its poster frame.
    static func reserve(
        fileName: String, fileSize: Int, kind: InAppEventMedia.Kind, isVideo: Bool, localizationID: String, previewFrameTimeCode: String? = nil
    ) -> PushRequest {
        var attributes: [String: Any] = ["fileName": fileName, "fileSize": fileSize, "appEventAssetType": kind.rawValue]
        if isVideo, let previewFrameTimeCode { attributes["previewFrameTimeCode"] = previewFrameTimeCode }
        return request(.post, collectionPath(isVideo: isVideo), [
            "data": [
                "type": type(isVideo: isVideo),
                "attributes": attributes,
                "relationships": ["appEventLocalization": ["data": ["type": "appEventLocalizations", "id": localizationID]]],
            ],
        ])
    }

    /// `PATCH …/{id}`: every part is up. Apple's update takes no checksum
    /// for event media.
    static func commit(id: String, isVideo: Bool, previewFrameTimeCode: String? = nil) -> PushRequest {
        var attributes: [String: Any] = ["uploaded": true]
        if isVideo, let previewFrameTimeCode { attributes["previewFrameTimeCode"] = previewFrameTimeCode }
        return request(.patch, "\(collectionPath(isVideo: isVideo))/\(id)", [
            "data": ["type": type(isVideo: isVideo), "id": id, "attributes": attributes],
        ])
    }

    /// `GET` one upload's delivery state after the commit.
    static func statusPath(id: String, isVideo: Bool) -> String {
        let field = isVideo ? "videoDeliveryState" : "assetDeliveryState"
        return "\(collectionPath(isVideo: isVideo))/\(id)?fields%5B\(type(isVideo: isVideo))%5D=\(field)"
    }

    /// `GET` a localization's images or videos with their asset types.
    static func existingPath(localizationID: String, isVideo: Bool) -> String {
        "/v1/appEventLocalizations/\(localizationID)/\(type(isVideo: isVideo))?fields%5B\(type(isVideo: isVideo))%5D=appEventAssetType&limit=50"
    }

    /// `DELETE …/{id}`.
    static func delete(id: String, isVideo: Bool) -> PushRequest {
        PushRequest(method: .delete, path: "\(collectionPath(isVideo: isVideo))/\(id)", body: nil)
    }

    // MARK: - Responses

    /// A reservation's ID and upload operations, in file order.
    static func reservation(in data: Data) throws -> (id: String, operations: [ScreenshotUploadOperation]) {
        let document = try JSONDecoder().decode(ScreenshotAPISingleDocument<AppEventMediaUploadAttributes>.self, from: data)
        let operations = document.data.attributes?.uploadOperations ?? []
        guard !operations.isEmpty else { throw AppStoreConnectError.unexpectedPayload }
        return (document.data.id, operations.sorted { $0.offset < $1.offset })
    }

    /// The delivery state in an upload's response, if it has one.
    static func deliveryState(in data: Data, isVideo: Bool) -> ScreenshotDeliveryState? {
        let document = try? JSONDecoder().decode(ScreenshotAPISingleDocument<AppEventMediaUploadAttributes>.self, from: data)
        return document?.data.attributes?.deliveryState(isVideo: isVideo)
    }

    /// The IDs in a localization's images or videos that are `kind`.
    static func existingIDs(in data: Data, kind: InAppEventMedia.Kind) throws -> [String] {
        let page = try JSONDecoder().decode(ScreenshotAPIDocument<AppEventMediaUploadAttributes, AppEventMediaUploadAttributes>.self, from: data)
        return page.data.filter { $0.attributes?.appEventAssetType == kind.rawValue }.map(\.id)
    }

    private static func request(_ method: PushRequest.Method, _ path: String, _ body: [String: Any]) -> PushRequest {
        let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
        return PushRequest(method: method, path: path, body: data)
    }
}

//
//  AppPreviewSetPush.swift
//  Atlas
//

import Foundation

/// One language's App Previews on one device for the version, changed by
/// hand in Screenshots (README-Manual): what the set holds after the push,
/// in order (live ones kept, files added or replacing one), and the live
/// ones it deletes. The push finds the version localization's set of that
/// device (or makes it), uploads the new videos and waits for Apple to
/// process them, then deletes, then puts the set in order: uploads go
/// first, so a failed upload never leaves a language with fewer App
/// Previews than before. The same steps as a product page's own App
/// Previews (`ProductPageScreenshotsPush`, `ProductPageMedia`).
///
/// It travels in Review & Push as a `POST /v1/appPreviewSets` whose body
/// is this push (`AppPreviewSetPush.Body`), never sent as is.
struct AppPreviewSetPush: Hashable, Sendable {
    struct Body: Codable, Hashable, Sendable {
        var versionAppPreviews: Content
    }

    /// One place in the set after the push.
    struct Slot: Codable, Hashable, Sendable {
        /// A live App Preview kept here; nil for a file.
        var liveID: String?
        /// "Lumen-de-1.mov".
        var fileName: String
        /// A video uploaded into this place; nil keeps the live one.
        var file: ProductPageScreenshotsPush.File?
        /// The live App Preview the file takes the place of, for the page's
        /// "Replaced" (it's among the push's deletes).
        var replacesID: String?
        /// The assistant that proposed the file (`propose_app_preview_file`).
        var proposedBy: String?
    }

    struct Content: Codable, Hashable, Sendable {
        var appID: String
        /// The `appStoreVersionLocalizations` ID.
        var localizationID: String
        var locale: String
        var displayType: ScreenshotDisplayType
        var slots: [Slot]
        /// Live App Previews the push deletes, after the uploads.
        var deletedIDs: [String]
    }

    static let path = "/v1/appPreviewSets"
    static let media = ProductPageMedia.appPreviews

    var content: Content

    init(_ content: Content) {
        self.content = content
    }

    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == Self.path, let body = request.body,
              let decoded = try? JSONDecoder().decode(Body.self, from: body)
        else { return nil }
        content = decoded.versionAppPreviews
    }

    var request: PushRequest {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let body = (try? encoder.encode(Body(versionAppPreviews: content))) ?? Data()
        return PushRequest(method: .post, path: Self.path, body: body)
    }

    /// Changes of one language's set wait for each other.
    var resourceKey: String { "appPreviews:\(content.localizationID):\(content.displayType.rawValue)" }

    /// The files it uploads, in order.
    var files: [ProductPageScreenshotsPush.File] { content.slots.compactMap(\.file) }

    // MARK: - Requests

    /// The version localization's App Preview set of this device, with what
    /// it holds.
    var setsPath: String {
        let kind = Self.media.setKind(content.displayType)
        return "/v1/appStoreVersionLocalizations/\(content.localizationID)/appPreviewSets"
            + "?filter%5BpreviewType%5D=\(kind)&include=appPreviews"
            + "&fields%5BappPreviewSets%5D=previewType,appPreviews&limit=50&limit%5BappPreviews%5D=\(Self.media.limit)"
    }

    var createSet: PushRequest {
        let body: [String: Any] = [
            "data": [
                "type": "appPreviewSets",
                "attributes": ["previewType": Self.media.setKind(content.displayType)],
                "relationships": [
                    "appStoreVersionLocalization": ["data": ["type": "appStoreVersionLocalizations", "id": content.localizationID]],
                ],
            ],
        ]
        let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
        return PushRequest(method: .post, path: Self.path, body: data)
    }
}

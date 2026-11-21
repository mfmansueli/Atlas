//
//  ProductPageMedia.swift
//  Atlas
//

import Foundation

/// What a page's set holds: screenshots, or App Previews (videos). Both go
/// through the same steps (find or make the set, reserve, upload, commit,
/// wait, delete the old, order), against their own resources.
enum ProductPageMedia: String, Codable, Hashable, Sendable {
    case screenshots
    case appPreviews

    /// How many a set takes.
    var limit: Int {
        switch self {
        case .screenshots: 10
        case .appPreviews: 3
        }
    }

    private var setType: String { self == .screenshots ? "appScreenshotSets" : "appPreviewSets" }
    private var itemType: String { self == .screenshots ? "appScreenshots" : "appPreviews" }
    private var setItem: String { self == .screenshots ? "appScreenshotSet" : "appPreviewSet" }
    private var kindField: String { self == .screenshots ? "screenshotDisplayType" : "previewType" }

    /// The set's kind as App Store Connect names it: "APP_IPHONE_67" for
    /// screenshots, "IPHONE_67" for App Previews.
    func setKind(_ displayType: ScreenshotDisplayType) -> String {
        switch self {
        case .screenshots: displayType.apiValue
        case .appPreviews: displayType.previewType ?? displayType.apiValue
        }
    }

    // MARK: - Requests

    func setsPath(localizationID: String, displayType: ScreenshotDisplayType) -> String {
        "/v1/appCustomProductPageLocalizations/\(localizationID)/\(setType)"
            + "?filter%5B\(kindField)%5D=\(setKind(displayType))&include=\(itemType)"
            + "&fields%5B\(setType)%5D=\(kindField),\(itemType)&limit=50&limit%5B\(itemType)%5D=\(limit)"
    }

    func createSet(localizationID: String, displayType: ScreenshotDisplayType) -> PushRequest {
        Self.request(.post, "/v1/\(setType)", [
            "data": [
                "type": setType,
                "attributes": [kindField: setKind(displayType)],
                "relationships": [
                    "appCustomProductPageLocalization": ["data": ["type": "appCustomProductPageLocalizations", "id": localizationID]],
                ],
            ],
        ])
    }

    /// Reserves one file's upload; an App Preview says its type.
    func reserve(_ file: ProductPageScreenshotsPush.File, fileSize: Int, setID: String) -> PushRequest {
        var attributes: [String: Any] = ["fileName": file.fileName, "fileSize": fileSize]
        if self == .appPreviews { attributes["mimeType"] = file.mimeType ?? Self.mimeType(of: file.fileName) }
        return Self.request(.post, "/v1/\(itemType)", [
            "data": [
                "type": itemType,
                "attributes": attributes,
                "relationships": [setItem: ["data": ["type": setType, "id": setID]]],
            ],
        ])
    }

    func commit(id: String, checksum: String) -> PushRequest {
        Self.request(.patch, "/v1/\(itemType)/\(id)", [
            "data": ["type": itemType, "id": id, "attributes": ["uploaded": true, "sourceFileChecksum": checksum]],
        ])
    }

    func statusPath(id: String) -> String {
        "/v1/\(itemType)/\(id)?fields%5B\(itemType)%5D=assetDeliveryState"
    }

    func delete(id: String) -> PushRequest {
        PushRequest(method: .delete, path: "/v1/\(itemType)/\(id)", body: nil)
    }

    func reorder(setID: String, ids: [String]) -> PushRequest {
        Self.request(.patch, "/v1/\(setType)/\(setID)/relationships/\(itemType)", [
            "data": ids.map { ["type": itemType, "id": $0] },
        ])
    }

    // MARK: - Responses

    /// The set of this kind in a sets response, and what it holds.
    func existingSet(in data: Data, displayType: ScreenshotDisplayType) throws -> (id: String, itemIDs: [String])? {
        let kind = setKind(displayType)
        switch self {
        case .screenshots:
            let page = try JSONDecoder().decode(ScreenshotAPIDocument<AppScreenshotSetAttributes, AppScreenshotAttributes>.self, from: data)
            return page.data.first { $0.attributes?.screenshotDisplayType == kind }.map { ($0.id, $0.related(itemType).map(\.id)) }
        case .appPreviews:
            let page = try JSONDecoder().decode(ScreenshotAPIDocument<AppPreviewSetAttributes, AppPreviewAttributes>.self, from: data)
            return page.data.first { $0.attributes?.previewType == kind }.map { ($0.id, $0.related(itemType).map(\.id)) }
        }
    }

    /// "video/quicktime" for .mov, "video/mp4" for .mp4 and .m4v.
    static func mimeType(of fileName: String) -> String {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "mov": "video/quicktime"
        case "m4v": "video/x-m4v"
        default: "video/mp4"
        }
    }

    private static func request(_ method: PushRequest.Method, _ path: String, _ body: [String: Any]) -> PushRequest {
        let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])
        return PushRequest(method: method, path: path, body: data)
    }
}

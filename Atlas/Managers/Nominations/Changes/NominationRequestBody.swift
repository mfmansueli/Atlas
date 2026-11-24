//
//  NominationRequestBody.swift
//  Atlas
//

import Foundation

/// The JSON:API documents `POST` and `PATCH /v1/nominations` take (App
/// Store Connect API 4.6.1). Create needs name, description, type,
/// publishStartDate, submitted and relatedApps; Atlas always creates a draft
/// (`submitted: false`) and submits in its own step. "Every country or
/// region" sends no `supportedTerritories`.
enum NominationRequestBody {
    /// `POST /v1/nominations`: a new draft.
    static func create(_ content: NominationContent) throws -> Data {
        var attributes = attributes(content, clearing: false)
        attributes["submitted"] = false
        let data: [String: Any] = [
            "type": "nominations",
            "attributes": attributes,
            "relationships": relationships(content, clearing: false),
        ]
        return try encode(["data": data])
    }

    /// `PATCH /v1/nominations/{id}` with every field of the draft: what's
    /// cleared is sent as null or empty, so App Store Connect forgets it.
    static func update(id: String, _ content: NominationContent) throws -> Data {
        let data: [String: Any] = [
            "type": "nominations",
            "id": id,
            "attributes": attributes(content, clearing: true),
            "relationships": relationships(content, clearing: true),
        ]
        return try encode(["data": data])
    }

    /// `PATCH /v1/nominations/{id}` sending it to Apple's editors. It can't
    /// be undone: after this, it can only be archived.
    static func submit(id: String) throws -> Data {
        try encode(["data": ["type": "nominations", "id": id, "attributes": ["submitted": true]]])
    }

    /// `PATCH /v1/nominations/{id}` archiving a submitted nomination.
    static func archive(id: String) throws -> Data {
        try encode(["data": ["type": "nominations", "id": id, "attributes": ["archived": true]]])
    }

    // MARK: - Parts

    private static func attributes(_ content: NominationContent, clearing: Bool) -> [String: Any] {
        var attributes: [String: Any] = [
            "name": content.trimmedName,
            "description": content.trimmedDescription,
            "launchInSelectMarketsFirst": content.launchInSelectMarketsFirst,
            "preOrderEnabled": content.preOrderEnabled,
            "hasInAppEvents": !content.eventIDs.isEmpty,
        ]
        if let type = content.type { attributes["type"] = type.rawValue }
        if let start = content.publishStart { attributes["publishStartDate"] = AppStoreConnectDate.text(start) }
        if let end = content.publishEnd {
            attributes["publishEndDate"] = AppStoreConnectDate.text(end)
        } else if clearing {
            attributes["publishEndDate"] = NSNull()
        }
        let devices = NominationDevice.allCases.filter(content.devices.contains).map(\.rawValue)
        if !devices.isEmpty || clearing { attributes["deviceFamilies"] = devices }
        if !content.locales.isEmpty || clearing { attributes["locales"] = content.locales }
        let links = content.materials.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if !links.isEmpty || clearing { attributes["supplementalMaterialsUris"] = links }
        if !content.trimmedNotes.isEmpty || clearing { attributes["notes"] = content.trimmedNotes }
        return attributes
    }

    private static func relationships(_ content: NominationContent, clearing: Bool) -> [String: Any] {
        var relationships: [String: Any] = ["relatedApps": linkage("apps", content.appIDs)]
        if !content.eventIDs.isEmpty || clearing { relationships["inAppEvents"] = linkage("appEvents", content.eventIDs) }
        if !content.territories.isEmpty {
            relationships["supportedTerritories"] = linkage("territories", content.territories)
        } else if clearing {
            // Back to every country or region: an update names them all.
            relationships["supportedTerritories"] = linkage("territories", TerritoryCatalog.standard.territories.map(\.id))
        }
        return relationships
    }

    private static func linkage(_ type: String, _ ids: [String]) -> [String: Any] {
        ["data": ids.map { ["type": type, "id": $0] }]
    }

    private static func encode(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    }
}

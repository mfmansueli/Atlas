//
//  ProductPageLocaleWrite.swift
//  Atlas
//

import Foundation

/// A write into a custom product page's version that takes edits: its
/// deep link, or one language's promotional text and keywords. Which
/// version that is only shows when it's sent: the one being prepared or
/// rejected, else a new one after the approved one (an approved version
/// can't change). The same push reuses that version for the page's other
/// changes. A language the version doesn't have is created.
///
/// It travels in Review & Push as a `POST /v1/appCustomProductPageLocalizations`
/// whose body is this write (`ProductPageLocaleWrite.Body`), never sent as is.
struct ProductPageLocaleWrite: Hashable, Sendable {
    struct Body: Codable, Hashable, Sendable {
        var productPageWrite: ProductPageLocaleWrite.Content
    }

    struct Content: Codable, Hashable, Sendable {
        /// The page; `{createdID:appCustomProductPages}` for one this push makes.
        var pageID: String
        /// The deep link of a version this write may have to create, so a
        /// new version keeps the approved one's.
        var currentDeepLink: String?
        var deepLink: String?
        var locale: String?
        /// Nil leaves the text as it is; "" clears it.
        var promotionalText: String?
        var addKeywords: [String] = []
        var removeKeywords: [String] = []
    }

    static let path = "/v1/appCustomProductPageLocalizations"
    static let versionType = "appCustomProductPageVersions"
    static let localizationType = "appCustomProductPageLocalizations"
    static let editableStates: Set<String> = ["PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "REJECTED"]

    var content: Content

    init(_ content: Content) {
        self.content = content
    }

    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == Self.path, let body = request.body,
              let decoded = try? JSONDecoder().decode(Body.self, from: body)
        else { return nil }
        content = decoded.productPageWrite
    }

    var request: PushRequest {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let body = (try? encoder.encode(Body(productPageWrite: content))) ?? Data()
        return PushRequest(method: .post, path: Self.path, body: body)
    }

    var pageID: String { content.pageID }

    // MARK: - Requests

    var versionsPath: String {
        "/v1/appCustomProductPages/\(content.pageID)/appCustomProductPageVersions?fields[appCustomProductPageVersions]=version,state,deepLink&limit=50"
    }

    var createVersion: PushRequest {
        var data: [String: Any] = [
            "type": Self.versionType,
            "relationships": ["appCustomProductPage": ["data": ["type": "appCustomProductPages", "id": content.pageID]]],
        ]
        if let link = content.deepLink ?? content.currentDeepLink, !link.isEmpty { data["attributes"] = ["deepLink": link] }
        return Self.request(.post, "/v1/\(Self.versionType)", ["data": data])
    }

    func updateDeepLink(versionID: String, to link: String) -> PushRequest {
        Self.request(.patch, "/v1/\(Self.versionType)/\(versionID)", [
            "data": ["type": Self.versionType, "id": versionID, "attributes": ["deepLink": link.isEmpty ? NSNull() as Any : link]],
        ])
    }

    func localizationsPath(versionID: String) -> String {
        "/v1/\(Self.versionType)/\(versionID)/appCustomProductPageLocalizations?fields[appCustomProductPageLocalizations]=locale,promotionalText&limit=50"
    }

    func createLocalization(versionID: String, locale: String) -> PushRequest {
        var attributes: [String: Any] = ["locale": locale]
        if let text = content.promotionalText, !text.isEmpty { attributes["promotionalText"] = text }
        return Self.request(.post, "/v1/\(Self.localizationType)", [
            "data": [
                "type": Self.localizationType, "attributes": attributes,
                "relationships": ["appCustomProductPageVersion": ["data": ["type": Self.versionType, "id": versionID]]],
            ],
        ])
    }

    func updateText(localizationID: String, to text: String) -> PushRequest {
        Self.request(.patch, "/v1/\(Self.localizationType)/\(localizationID)", [
            "data": ["type": Self.localizationType, "id": localizationID, "attributes": ["promotionalText": text.isEmpty ? NSNull() as Any : text]],
        ])
    }

    /// `POST` or `DELETE` the page language's keywords (`appKeywords`; the
    /// ID is the word).
    func keywords(_ method: PushRequest.Method, _ words: [String], localizationID: String) -> PushRequest {
        Self.request(method, "/v1/\(Self.localizationType)/\(localizationID)/relationships/searchKeywords", [
            "data": words.map { ["type": "appKeywords", "id": $0] },
        ])
    }

    // MARK: - Sending

    /// Sends it into `knownVersionID`, else the version that takes edits,
    /// else a new one. Returns the version and the language, with the last
    /// response's rate limit.
    func send(
        via transport: any PushTransport,
        knownVersionID: String?
    ) async throws -> (versionID: String, localizationID: String?, rateLimit: AppStoreConnectRateLimit?) {
        var rateLimit: AppStoreConnectRateLimit?
        let versionID: String
        var createdVersion = false
        if let knownVersionID {
            versionID = knownVersionID
        } else {
            let versions = try await transport.fetch(versionsPath)
            rateLimit = versions.rateLimit
            if let editable = Self.editableVersionID(in: versions.data) {
                versionID = editable
            } else {
                let created = try await transport.send(createVersion)
                rateLimit = created.rateLimit ?? rateLimit
                guard let id = Self.createdID(in: created.data) else { throw AppStoreConnectError.unexpectedPayload }
                versionID = id
                createdVersion = true
            }
        }
        // A version made here already has the new deep link.
        if let link = content.deepLink, !createdVersion {
            let response = try await transport.send(updateDeepLink(versionID: versionID, to: link))
            rateLimit = response.rateLimit ?? rateLimit
        }
        guard let locale = content.locale else { return (versionID, nil, rateLimit) }
        let language = try await localization(locale, versionID: versionID, via: transport)
        rateLimit = language.rateLimit ?? rateLimit
        let localizationID = language.id
        if !content.removeKeywords.isEmpty {
            let response = try await transport.send(keywords(.delete, content.removeKeywords, localizationID: localizationID))
            rateLimit = response.rateLimit ?? rateLimit
        }
        if !content.addKeywords.isEmpty {
            let response = try await transport.send(keywords(.post, content.addKeywords, localizationID: localizationID))
            rateLimit = response.rateLimit ?? rateLimit
        }
        return (versionID, localizationID, rateLimit)
    }

    /// The version's language for `locale` with this write's text: the one
    /// there (its text updated), else a new one with the text. One refused
    /// as a duplicate was made meanwhile (e.g. by an earlier try Apple
    /// answered with a server error): it's that one.
    private func localization(
        _ locale: String, versionID: String, via transport: any PushTransport
    ) async throws -> (id: String, rateLimit: AppStoreConnectRateLimit?) {
        let localizations = try await transport.fetch(localizationsPath(versionID: versionID))
        if let existing = Self.localizationID(for: locale, in: localizations.data) {
            return try await (existing, writeText(into: existing, via: transport) ?? localizations.rateLimit)
        }
        do {
            let created = try await transport.send(createLocalization(versionID: versionID, locale: locale))
            guard let id = Self.createdID(in: created.data) else { throw AppStoreConnectError.unexpectedPayload }
            return (id, created.rateLimit)
        } catch let error as AppStoreConnectError where error.isDuplicate {
            let again = try await transport.fetch(localizationsPath(versionID: versionID))
            guard let existing = Self.localizationID(for: locale, in: again.data) else { throw error }
            return try await (existing, writeText(into: existing, via: transport) ?? again.rateLimit)
        }
    }

    /// Writes this write's text into the language, when it has one; returns
    /// the rate limit.
    private func writeText(into localizationID: String, via transport: any PushTransport) async throws -> AppStoreConnectRateLimit? {
        guard let text = content.promotionalText else { return nil }
        return try await transport.send(updateText(localizationID: localizationID, to: text)).rateLimit
    }

    /// The newest version that takes edits.
    static func editableVersionID(in data: Data) -> String? {
        resources(in: data)
            .filter { editableStates.contains(attributes(of: $0)["state"] as? String ?? "") }
            .max { number(of: $0) < number(of: $1) }?["id"] as? String
    }

    /// `version` is a string ("2") in API 4.6.
    private static func number(of resource: [String: Any]) -> Int {
        let value = attributes(of: resource)["version"]
        return (value as? Int) ?? Int(value as? String ?? "") ?? 0
    }

    static func localizationID(for locale: String, in data: Data) -> String? {
        resources(in: data).first { attributes(of: $0)["locale"] as? String == locale }?["id"] as? String
    }

    private static func createdID(in data: Data) -> String? {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (object?["data"] as? [String: Any])?["id"] as? String
    }

    private static func resources(in data: Data) -> [[String: Any]] {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return object?["data"] as? [[String: Any]] ?? []
    }

    private static func attributes(of resource: [String: Any]) -> [String: Any] {
        resource["attributes"] as? [String: Any] ?? [:]
    }

    private static func request(_ method: PushRequest.Method, _ path: String, _ body: [String: Any]) -> PushRequest {
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
        return PushRequest(method: method, path: path, body: data)
    }
}

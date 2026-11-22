//
//  FakeNewPageTransport.swift
//  AtlasTests
//

import Foundation
import Synchronization
@testable import Atlas

/// App Store Connect making one new custom product page ("page-made", its
/// version "ver-1"), which can fail the way Apple did on Alba: the create
/// answers with an error and the page is made anyway, listed only after a
/// few looks, or never. Writes are logged in short form ("create page",
/// "create language de-DE", "keywords loc-de-DE", "text loc-ja").
final class FakeNewPageTransport: PushTransport {
    struct Setup {
        var appID = "lumen"
        var name = "Private diary"
        /// What the create answers with instead of the page.
        var createFailure: (any Error)?
        /// Apple makes the page even when the create fails.
        var madeAnyway = true
        /// Page lists after the create that don't show it yet.
        var hiddenForLooks = 0
        /// A page of that name is there before anything is sent.
        var pageBefore = false
        /// The page's version is listed with it.
        var versionReady = true
        /// The languages Apple makes on the version; nil: every one the
        /// create had.
        var madeLocales: [String]?
        /// Languages "ver-1" has before anything is sent.
        var initialLocales: [String] = []
        /// Languages there that the first listing leaves out (made
        /// meanwhile): creating one is refused as a duplicate.
        var lateLocales: Set<String> = []
        /// Writes whose path contains the key fail with the error, this
        /// many times.
        var failures: [String: (error: any Error, times: Int)] = [:]
    }

    private struct State {
        var setup: Setup
        var log: [String] = []
        var createSent = false
        var made = false
        var looks = 0
        var locales: [String: String] = [:]
        var localeListings = 0
    }

    static let pageID = "page-made"
    static let versionID = "ver-1"

    private let state: Mutex<State>

    init(_ setup: Setup = Setup()) {
        var initial = State(setup: setup)
        initial.made = setup.pageBefore
        for locale in setup.initialLocales {
            initial.locales[locale] = ""
        }
        state = Mutex(initial)
    }

    var log: [String] { state.withLock { $0.log } }
    var pagesPath: String { ProductPageScreenshotsPush.pagesPath(appID: state.withLock { $0.setup.appID }) }

    /// Apple finishes the page now (after the push gave up looking).
    func finishPage(versionReady: Bool = true) {
        state.withLock { state in
            state.made = true
            state.setup.hiddenForLooks = 0
            state.setup.versionReady = versionReady
        }
    }

    func fetch(_ path: String) async throws -> AppStoreConnectResponse {
        let data: Data = state.withLock { state in
            if path == ProductPageScreenshotsPush.pagesPath(appID: state.setup.appID) {
                state.log.append("list pages")
                if state.createSent { state.looks += 1 }
                let listed = state.made && (state.setup.pageBefore || state.looks > state.setup.hiddenForLooks)
                let pages = listed ? [["type": "appCustomProductPages", "id": Self.pageID, "attributes": ["name": state.setup.name]]] : []
                return Self.json(["data": pages])
            }
            if path.hasPrefix("/v1/appCustomProductPages/\(Self.pageID)/appCustomProductPageVersions") {
                state.log.append("versions")
                let versions = state.setup.versionReady
                    ? [["type": "appCustomProductPageVersions", "id": Self.versionID, "attributes": ["state": "PREPARE_FOR_SUBMISSION", "version": "1"]]]
                    : []
                return Self.json(["data": versions])
            }
            if path.hasPrefix("/v1/appCustomProductPageVersions/\(Self.versionID)/appCustomProductPageLocalizations") {
                state.log.append("languages")
                state.localeListings += 1
                let hidden = state.localeListings == 1 ? state.setup.lateLocales : []
                let listed = state.locales.keys.sorted().filter { !hidden.contains($0) }.map { locale in
                    ["type": "appCustomProductPageLocalizations", "id": "loc-\(locale)", "attributes": ["locale": locale]]
                }
                return Self.json(["data": listed])
            }
            state.log.append("GET \(path)")
            return Data("{}".utf8)
        }
        return AppStoreConnectResponse(data: data, rateLimit: nil)
    }

    func send(_ request: PushRequest) async throws -> AppStoreConnectResponse {
        let data = try state.withLock { state throws -> Data in
            if let failure = state.setup.failures.first(where: { request.path.contains($0.key) && $0.value.times > 0 }) {
                state.setup.failures[failure.key]?.times -= 1
                state.log.append("failed \(request.method.rawValue) \(failure.key)")
                throw failure.value.error
            }
            return try Self.answer(request, state: &state)
        }
        return AppStoreConnectResponse(data: data, rateLimit: nil)
    }

    private static func answer(_ request: PushRequest, state: inout State) throws -> Data {
        let body = request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let attributes = (body["data"] as? [String: Any])?["attributes"] as? [String: Any] ?? [:]
        switch (request.method, request.path) {
        case (.post, "/v1/appCustomProductPages"):
            state.log.append("create page")
            state.createSent = true
            let included = body["included"] as? [[String: Any]] ?? []
            let inline = included.compactMap { ($0["attributes"] as? [String: Any])?["locale"] as? String }
            let failure = state.setup.createFailure
            if failure == nil || state.setup.madeAnyway {
                state.made = true
                for locale in state.setup.madeLocales ?? inline {
                    state.locales[locale] = ""
                }
            }
            if let failure { throw failure }
            return json(["data": ["type": "appCustomProductPages", "id": pageID]])
        case (.post, "/v1/appCustomProductPageLocalizations"):
            let locale = attributes["locale"] as? String ?? ""
            state.log.append("create language \(locale)")
            guard state.locales[locale] == nil else {
                throw AppStoreConnectError.rejected(statusCode: 409, code: "ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE", detail: nil)
            }
            state.locales[locale] = attributes["promotionalText"] as? String ?? ""
            return json(["data": ["type": "appCustomProductPageLocalizations", "id": "loc-\(locale)"]])
        case (.post, "/v1/appCustomProductPageVersions"):
            state.log.append("create version")
            return json(["data": ["type": "appCustomProductPageVersions", "id": "ver-new"]])
        default:
            if request.path.hasSuffix("/relationships/searchKeywords") {
                let id = request.path.split(separator: "/")[2]
                state.log.append("keywords \(id)")
            } else if request.path.hasPrefix("/v1/appCustomProductPageLocalizations/") {
                state.log.append("text \(request.path.split(separator: "/")[2])")
            } else {
                state.log.append("\(request.method.rawValue) \(request.path)")
            }
            return Data("{}".utf8)
        }
    }

    /// The text a language was made with.
    func text(of locale: String) -> String? {
        state.withLock { $0.locales[locale] }
    }

    private static func json(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }
}

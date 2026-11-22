//
//  ProductPageCreate.swift
//  Atlas
//

import Foundation

/// A new custom product page's `POST /v1/appCustomProductPages`: the page,
/// its first version and its languages in one request. Apple's server can
/// give up on it and still make the page: on Alba, a page made from a
/// 14-language version answered `UNEXPECTED_ERROR` after 30–60 s and was
/// there minutes later. So:
///
/// - Before sending, a page of that name already there isn't made again
///   (`ProductPageAlreadyMade`), unless this change's own earlier create may
///   have made it (`mayHaveMadeItBefore`): then it's that page.
/// - After a 5xx, a timeout or an answer without the page's ID, Atlas looks
///   for the page of that name for about 2 minutes
///   (`ProductPagePushPacing.looks`). Found with a version that takes
///   edits, it's the page this change made: the languages Apple didn't make
///   are made with their texts, and the change goes on.
/// - It's never sent a second time by itself: not finding the page doesn't
///   prove Apple won't still make it (`ProductPageNotConfirmed`).
///
/// No page of that name was there when it was sent, so the one that shows
/// up afterwards is the one it made.
struct ProductPageCreate: Hashable, Sendable {
    struct Language: Hashable, Sendable {
        var locale: String
        var promotionalText: String?
    }

    /// Where it's sent: the app, what this push knows of its pages, and how
    /// long to look for a page Apple failed on.
    @MainActor
    struct Context {
        var appID: StoreApp.ID
        var state: ProductPagePushState
        var transport: any PushTransport
        var pacing: ProductPagePushPacing
    }

    var request: PushRequest
    var name: String
    var deepLink: String?
    /// The languages the request makes inline, each with its text.
    var languages: [Language]

    init?(_ request: PushRequest) {
        guard let name = ProductPageAlreadyMade.name(creating: request), let body = request.body else { return nil }
        self.request = request
        self.name = name
        let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        let included = object?["included"] as? [[String: Any]] ?? []
        var deepLink: String?
        var languages: [Language] = []
        for resource in included {
            let attributes = resource["attributes"] as? [String: Any] ?? [:]
            switch resource["type"] as? String {
            case ProductPageLocaleWrite.versionType:
                deepLink = attributes["deepLink"] as? String
            case ProductPageLocaleWrite.localizationType:
                guard let locale = attributes["locale"] as? String else { continue }
                languages.append(Language(locale: locale, promotionalText: attributes["promotionalText"] as? String))
            default:
                continue
            }
        }
        self.deepLink = deepLink
        self.languages = languages
    }

    /// Makes the page, or takes the one Apple made from this request
    /// although it answered with an error. Returns its ID; `made` hears it
    /// as soon as it's known, before the missing languages are made.
    @MainActor
    func send(
        in context: Context,
        mayHaveMadeItBefore: Bool,
        note: (AppStoreConnectRateLimit?) -> Void,
        looking: () -> Void,
        made: (String) -> Void
    ) async throws -> String {
        if let existing = try await pageID(in: context, note: note) {
            guard mayHaveMadeItBefore else { throw ProductPageAlreadyMade(name: name) }
            made(existing)
            guard let versionID = try await editableVersion(of: existing, in: context, note: note) else {
                throw ProductPageNotConfirmed(name: name, error: nil, pageSeen: true, looked: .zero)
            }
            try await makeMissingLanguages(pageID: existing, versionID: versionID, in: context, note: note)
            return existing
        }
        let failure: any Error
        do {
            let response = try await context.transport.send(request)
            note(response.rateLimit)
            if let id = Self.createdID(in: response.data) {
                made(id)
                return id
            }
            failure = AppStoreConnectError.unexpectedPayload
        } catch where PushController.mayHaveGoneThrough(error) {
            failure = error
        }
        looking()
        return try await takeWhatAppleMade(after: failure, in: context, note: note, made: made)
    }

    /// Looks for the page Apple may have made after failing; throws
    /// `ProductPageNotConfirmed` when it isn't there ready.
    @MainActor
    private func takeWhatAppleMade(
        after failure: any Error, in context: Context, note: (AppStoreConnectRateLimit?) -> Void, made: (String) -> Void
    ) async throws -> String {
        var seen: String?
        for wait in context.pacing.looks {
            try await Task.sleep(for: wait)
            // A look that fails is one less look, not the change's failure.
            guard let found = await lookUp({ try await pageID(in: context, note: note) }) else { continue }
            if seen == nil { made(found) }
            seen = found
            guard let versionID = await lookUp({ try await editableVersion(of: found, in: context, note: note) }) else { continue }
            try await makeMissingLanguages(pageID: found, versionID: versionID, in: context, note: note)
            return found
        }
        throw ProductPageNotConfirmed(name: name, error: failure, pageSeen: seen != nil, looked: context.pacing.looking)
    }

    /// What a look found; nil when it found nothing or failed.
    @MainActor
    private func lookUp(_ look: () async throws -> String?) async -> String? {
        do {
            return try await look()
        } catch {
            return nil
        }
    }

    /// The ID of the app's page with this name, if there is one.
    @MainActor
    private func pageID(in context: Context, note: (AppStoreConnectRateLimit?) -> Void) async throws -> String? {
        let pages = try await context.transport.fetch(ProductPageScreenshotsPush.pagesPath(appID: context.appID))
        note(pages.rateLimit)
        return ProductPageScreenshotsPush.pageID(named: name, in: pages.data)
    }

    /// The page's version that takes edits, kept for the page's other
    /// writes in this push; nil while Apple hasn't made one.
    @MainActor
    private func editableVersion(of pageID: String, in context: Context, note: (AppStoreConnectRateLimit?) -> Void) async throws -> String? {
        if let known = context.state.versions[pageID] { return known }
        let write = ProductPageLocaleWrite(.init(pageID: pageID, currentDeepLink: deepLink))
        let versions = try await context.transport.fetch(write.versionsPath)
        note(versions.rateLimit)
        guard let versionID = ProductPageLocaleWrite.editableVersionID(in: versions.data) else { return nil }
        context.state.versions[pageID] = versionID
        return versionID
    }

    /// Makes, with their texts, the languages the request had that the
    /// page's version hasn't. Languages that are there are left alone: Apple
    /// made them from this same request.
    @MainActor
    private func makeMissingLanguages(
        pageID: String, versionID: String, in context: Context, note: (AppStoreConnectRateLimit?) -> Void
    ) async throws {
        guard !languages.isEmpty else { return }
        let transport = context.transport
        let lookup = ProductPageLocaleWrite(.init(pageID: pageID, currentDeepLink: deepLink))
        let response = try await transport.fetch(lookup.localizationsPath(versionID: versionID))
        note(response.rateLimit)
        for language in languages where ProductPageLocaleWrite.localizationID(for: language.locale, in: response.data) == nil {
            let write = ProductPageLocaleWrite(.init(
                pageID: pageID, currentDeepLink: deepLink, locale: language.locale, promotionalText: language.promotionalText
            ))
            let sent = try await write.send(via: transport, knownVersionID: versionID)
            note(sent.rateLimit)
        }
    }

    private static func createdID(in data: Data) -> String? {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (object?["data"] as? [String: Any])?["id"] as? String
    }
}

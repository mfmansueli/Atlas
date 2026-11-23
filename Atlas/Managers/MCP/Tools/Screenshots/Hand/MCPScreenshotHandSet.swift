//
//  MCPScreenshotHandSet.swift
//  Atlas
//

import Foundation

/// A language's screenshots on one device as the screenshot tools see
/// them: the set as the person left it on the language page, or as it
/// starts (the template's slots, or what's live in a language or on a
/// device Atlas doesn't render, read from App Store Connect only then).
/// `get_screenshot_context` lists it; `propose_screenshot_removal` and
/// `propose_screenshot_order` name its screenshots by position or ID.
@MainActor
struct MCPScreenshotHandSet {
    let locale: StoreLocale
    let displayType: ScreenshotDisplayType
    let set: ScreenshotHandSet
    /// The language is the app's primary one, which must keep one.
    let isPrimary: Bool

    var places: [ScreenshotHandPlace] { ScreenshotHandPlace.kept(in: set) }

    static func load(
        _ draft: MCPScreenshotsDraft,
        locale: StoreLocale,
        displayType: ScreenshotDisplayType,
        in workspace: MCPWorkspace
    ) async throws -> MCPScreenshotHandSet {
        let document = draft.document
        let needsLive = document.handSet(locale: locale.code, displayType: displayType) == nil
            && !document.rendersByTemplate(locale: locale.code, displayType: displayType)
        let live = needsLive ? try await Self.live(for: draft.app, services: draft.services, in: workspace) : LiveScreenshots()
        return MCPScreenshotHandSet(
            locale: locale,
            displayType: displayType,
            set: document.handSetOrStart(locale: locale.code, displayType: displayType, live: live),
            isPrimary: locale.code == draft.primary.code
        )
    }

    /// What's live on the version being prepared, as the Screenshots view
    /// reads it.
    private static func live(for app: StoreApp, services: any ScreenshotsServices, in workspace: MCPWorkspace) async throws -> LiveScreenshots {
        let storePage = workspace.services.storePage
        do {
            let content = try await storePage.content(for: app, versionID: nil)
            var context = ScreenshotsContext(content: content)
            await context.readPlatformLocalizations(in: content) { id in try await storePage.content(for: app, versionID: id) }
            return try await services.liveScreenshots(for: app, context: context)
        } catch {
            throw MCPToolError.unavailable(String(localized: "Couldn’t read \(app.name)’s screenshots on the App Store: \(error.localizedDescription)"))
        }
    }

    /// The display type an assistant named, among the devices sets are
    /// edited on.
    static func displayType(_ value: String) throws -> ScreenshotDisplayType {
        guard let display = ScreenshotDisplayType(mcpValue: value), ScreenshotDisplayType.studio.contains(display) else {
            throw MCPToolError.invalidArgument(name: "displayType", expected: "iphone, iphone_duo, ipad, mac, watch or vision_pro")
        }
        return display
    }

    // MARK: - Naming

    /// Why a proposal can't name what it names: the reason it's refused
    /// with.
    struct Refusal: Error {
        let reason: String

        init(_ reason: String) {
            self.reason = reason
        }
    }

    /// The places named by `positions` (from 1) and `ids` (as listed), in
    /// the order given, positions first; or why one isn't there.
    func places(positions: [Int], ids: [String]) -> Result<[ScreenshotHandPlace], Refusal> {
        let places = places
        var named: [ScreenshotHandPlace] = []
        for position in positions {
            guard places.indices.contains(position - 1) else {
                return .failure(Refusal(String(localized: """
                There’s no screenshot \(position): \(locale.name) has \(places.count) on \(displayType.title), from 1 to \(places.count).
                """)))
            }
            named.append(places[position - 1])
        }
        for id in ids {
            guard let place = places.first(where: { $0.mcpID == id }) else {
                return .failure(Refusal(String(localized: """
                No screenshot “\(id)” in \(locale.name) on \(displayType.title). Read the IDs in get_screenshot_context with this locale and displayType.
                """)))
            }
            named.append(place)
        }
        guard Set(named.map(\.mcpID)).count == named.count else {
            return .failure(Refusal(String(localized: "A screenshot is named twice. Name each one once.")))
        }
        return .success(named)
    }

    // MARK: - Reading

    /// `{locale, displayType, screenshots: [{position, id, madeBy, …}],
    /// deletedOnPush}`, for `get_screenshot_context`.
    var json: JSONValue {
        let screenshots = places.map { place -> JSONValue in
            var entry: [String: JSONValue] = [
                "position": .int(place.position + 1),
                "id": .string(place.mcpID),
                "madeBy": .string(place.madeBy),
            ]
            if let slot = place.base?.templateSlot, place.fileID == nil { entry["templateSlot"] = .int(slot + 1) }
            if let name = place.fileName {
                entry["fileName"] = .string(name)
            } else if case let .live(_, fileName, _) = place.base, !fileName.isEmpty {
                entry["fileName"] = .string(fileName)
            }
            return .object(entry)
        }
        var result: [String: JSONValue] = [
            "locale": .string(locale.code),
            "displayType": .string(displayType.mcpValue),
            "screenshots": .array(screenshots),
            "deletedOnPush": .int(set.slots.count(where: \.isDeleted)),
        ]
        if places.isEmpty, !isPrimary { result["note"] = .string(String(localized: "No screenshots of its own: the App Store shows the primary language’s.")) }
        return .object(result)
    }
}

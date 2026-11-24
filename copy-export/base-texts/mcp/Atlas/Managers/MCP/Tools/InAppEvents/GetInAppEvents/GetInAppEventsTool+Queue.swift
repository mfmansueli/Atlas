//
//  GetInAppEventsTool+Queue.swift
//  Atlas
//

import Foundation

// What an event has waiting in Review & Push, as `get_in_app_events`
// shows it: the texts per language (`queuedTexts`) and each art upload
// with the file Atlas sends (`queuedArtwork`, grouped by file in
// `queuedArtworkSummary`), so an assistant can tell what was chosen
// without notes of its own.
extension GetInAppEventsTool {
    /// `{locale, changeId, changeIds, newLanguage, waitingForAcceptance,
    /// by, name, shortDescription, longDescription, pushStatus}`; a text
    /// that isn't queued is left out (App Store Connect's stays).
    static func queuedTextsJSON(_ queued: [InAppEventQueuedTexts], push: [MCPPushSnapshot.Item] = []) -> JSONValue {
        .array(queued.map { item in
            var object: [String: JSONValue] = [
                "locale": .string(item.locale),
                "changeId": .string(item.changeIDs.first ?? ""),
                "changeIds": .array(item.changeIDs.map(JSONValue.string)),
                "newLanguage": .bool(item.isNewLanguage),
                "waitingForAcceptance": .bool(item.isAwaitingAcceptance),
                "by": .string(item.sources.map(\.title).joined(separator: ", ")),
            ]
            for field in InAppEventField.allCases {
                if let text = item.texts[field] { object[field.rawValue] = .string(text) }
            }
            let pushed = push.filter { item.changeIDs.contains($0.changeID) }
            if let status = Self.mostActive(pushed) { object.merge(pushStatusJSON(status)) { $1 } }
            return .object(object)
        })
    }

    /// One art upload waiting in Review & Push, with the file Atlas sends:
    /// its path on this Mac (open it to see exactly what goes), size,
    /// pixels, a video's length and poster frame, the name it came with,
    /// its SHA-256 and where it came from. `languageExists`: App Store
    /// Connect has the item's language already (a language queued as new
    /// and pushed since keeps its placeholder, found again at push).
    /// `copies` says whether it's the primary language's art again.
    static func queuedArtworkJSON(
        _ item: InAppEventQueuedArtwork, file: InAppEventArtworkFile?, languageExists: Bool = true, info: InAppEventArtworkFileInfo? = nil,
        copies: InAppEventArtworkCopies? = nil, stored: [InAppEventArtworkStoredFile] = [], push: MCPPushSnapshot.Item? = nil
    ) -> JSONValue {
        var object: [String: JSONValue] = [
            "changeId": .string(item.changeID), "kind": .string(item.kind.mcpValue), "locale": .string(item.locale),
            "file": .string(item.push.fileName), "isVideo": .bool(item.push.isVideo),
            "waitingForAcceptance": .bool(item.isAwaitingAcceptance), "by": .string(item.source.title),
            "path": .string(item.push.path),
            "fileSize": .int(item.push.fileSize),
            "fileExists": .bool(file != nil),
        ]
        if let timeCode = item.push.previewFrameTimeCode { object["previewFrameTimeCode"] = .string(timeCode) }
        if let file {
            object["width"] = .int(file.pixelSize.width)
            object["height"] = .int(file.pixelSize.height)
            if let seconds = file.seconds { object["seconds"] = .double((seconds * 10).rounded() / 10) }
        }
        if !languageExists, EventLocalizationPlaceholder.isPlaceholder(item.push.localizationID) {
            object["languageCreatedByPush"] = true
        }
        if let info { object.merge(info.json) { $1 } }
        let fingerprint = InAppEventArtworkFingerprint(item.push, info: info)
        if let copies {
            if copies.isCopy(fingerprint, kind: item.kind, locale: item.locale) {
                object["sameAsPrimary"] = true
                object["copyNeeded"] = .bool(copies.hasOwn(item.kind, locale: item.locale))
            }
            let own = copies.event.localization(item.locale)?.media.first { $0.kind == item.kind }
            if let own, InAppEventArtworkFingerprint(own, stored: stored).isSameFile(as: fingerprint) {
                object["alreadyInAppStoreConnect"] = true
            }
        }
        if let push { object.merge(pushStatusJSON(push)) { $1 } }
        return .object(object)
    }

    /// The queued art by kind and file: `{kind, file, path, isVideo,
    /// originalName, sha256, origin, locales, changeIds}`, the card first.
    static func queuedArtworkSummaryJSON(_ queued: [InAppEventQueuedArtwork], infos: [String: InAppEventArtworkFileInfo]) -> JSONValue {
        .array(InAppEventArtworkProposal.grouped(queued).map { proposal in
            var object: [String: JSONValue] = [
                "kind": .string(proposal.kind.mcpValue),
                "file": .string(proposal.push.fileName),
                "path": .string(proposal.push.path),
                "isVideo": .bool(proposal.push.isVideo),
                "locales": .array(proposal.locales.map(JSONValue.string)),
                "changeIds": .array(proposal.items.map { .string($0.changeID) }),
            ]
            if let info = infos[proposal.push.path] { object.merge(info.json) { $1 } }
            return .object(object)
        })
    }

    /// `pushStatus` (and `pushProgress` or `pushReason`) of a change in the
    /// push.
    static func pushStatusJSON(_ item: MCPPushSnapshot.Item) -> [String: JSONValue] {
        var object: [String: JSONValue] = ["pushStatus": .string(item.statusName)]
        if let progress = item.json["progress"] { object["pushProgress"] = progress }
        if let reason = item.json["reason"] { object["pushReason"] = reason }
        return object
    }

    /// Of a language's changes in the push, the one that says most: one
    /// being sent, then one that failed, then one waiting, then the rest.
    private static func mostActive(_ items: [MCPPushSnapshot.Item]) -> MCPPushSnapshot.Item? {
        let order = ["sending", "failed", "conflict", "notSent", "queued", "done"]
        return items.min { (order.firstIndex(of: $0.statusName) ?? order.count) < (order.firstIndex(of: $1.statusName) ?? order.count) }
    }

    /// The files the queued art sends, read once each (many languages
    /// share one).
    static func files(of queued: [InAppEventQueuedArtwork]) async -> [String: InAppEventArtworkFile] {
        var files: [String: InAppEventArtworkFile] = [:]
        for path in Set(queued.map(\.push.path)) {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path),
                  let file = await InAppEventArtworkInspector.inspect(url)
            else { continue }
            files[path] = file
        }
        return files
    }
}

//
//  GetInAppEventsTool+Queue.swift
//  Atlas
//

import Foundation

// What an event has waiting in Review & Push, as `get_in_app_events`
// shows it: the texts per language (`queuedTexts`) and each art upload
// with the file Atlas sends (`queuedArtwork`), so an assistant can tell
// what was chosen without notes of its own.
extension GetInAppEventsTool {
    /// `{locale, changeId, changeIds, newLanguage, waitingForAcceptance,
    /// by, name, shortDescription, longDescription}`; a text that isn't
    /// queued is left out (App Store Connect's stays).
    static func queuedTextsJSON(_ queued: [InAppEventQueuedTexts]) -> JSONValue {
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
            return .object(object)
        })
    }

    /// One art upload waiting in Review & Push, with the file Atlas sends:
    /// its path on this Mac (open it to see exactly what goes), size,
    /// pixels, a video's length and poster frame. `languageExists`: App
    /// Store Connect has the item's language already (a language queued as
    /// new and pushed since keeps its placeholder, found again at push).
    static func queuedArtworkJSON(_ item: InAppEventQueuedArtwork, file: InAppEventArtworkFile?, languageExists: Bool = true) -> JSONValue {
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
        return .object(object)
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

//
//  GetInAppEventsTool+MediaDetails.swift
//  Atlas
//

import Foundation

// What App Store Connect has as each language's card and details page,
// beside `media`'s one-line text: the file's name and size as it was
// uploaded, the poster frame and Apple's processing, which file Atlas sent
// it from, and the language's queued changes that send the same file.
extension GetInAppEventsTool {
    /// `mediaDetails[locale][kind]`; a kind no language shows is left out.
    static func mediaDetailsJSON(_ state: InAppEventMediaState, queued: [InAppEventQueuedArtwork], reading: MediaReading) -> JSONValue {
        let primaryLocale = state.languages.first?.primaryLocale
        let primary = state.languages.first { $0.locale == primaryLocale }
        return .object(Dictionary(uniqueKeysWithValues: state.languages.map { language in
            var kinds: [String: JSONValue] = [:]
            for kind in InAppEventMedia.Kind.allCases {
                if let media = language.own[kind] {
                    var object = details(media, queued: queued.filter { $0.kind == kind && $0.locale == language.locale }, reading: reading)
                    if language.locale != primaryLocale, let theirs = primary?.own[kind],
                       InAppEventArtworkFingerprint(theirs, stored: reading.stored).isSameFile(as: InAppEventArtworkFingerprint(media, stored: reading.stored))
                    {
                        object["sameAsPrimary"] = true
                    }
                    kinds[kind.mcpValue] = .object(object)
                } else if let media = language.fallback[kind], let primaryLocale {
                    var object = details(media, queued: queued.filter { $0.kind == kind && $0.locale == language.locale }, reading: reading)
                    object["shownFrom"] = .string(primaryLocale)
                    kinds[kind.mcpValue] = .object(object)
                }
            }
            return (language.locale, JSONValue.object(kinds))
        }))
    }

    /// One image or video as App Store Connect has it.
    private static func details(_ media: InAppEventMedia, queued: [InAppEventQueuedArtwork], reading: MediaReading) -> [String: JSONValue] {
        var object = fields(of: media)
        let fingerprint = InAppEventArtworkFingerprint(media, stored: reading.stored)
        if let file = InAppEventArtworkStoredFile.matching(fileName: media.fileName, fileSize: media.fileSize, in: reading.stored).first {
            var atlas: [String: JSONValue] = ["fileId": .string(file.fileID), "path": .string(file.path)]
            if let info = file.info { atlas.merge(info.json) { $1 } }
            object["atlasFile"] = .object(atlas)
        }
        let same = queued.filter { InAppEventArtworkFingerprint($0.push, info: reading.infos[$0.push.path]).isSameFile(as: fingerprint) }
        if !same.isEmpty { object["matchesQueued"] = .array(same.map { .string($0.changeID) }) }
        return object
    }

    /// What Apple says of the file; a field it leaves out is left out.
    private static func fields(of media: InAppEventMedia) -> [String: JSONValue] {
        let optional: [String: JSONValue?] = [
            "fileName": media.fileName.map(JSONValue.string),
            "fileSize": media.fileSize.map(JSONValue.int),
            "width": media.width.map(JSONValue.int),
            "height": media.height.map(JSONValue.int),
            "previewFrameTimeCode": media.previewFrameTimeCode.map(JSONValue.string),
            "imageUrl": media.imageURL.map { .string($0.absoluteString) },
            "state": media.state.map(JSONValue.string),
            "stateErrors": media.stateErrors.isEmpty ? nil : .array(media.stateErrors.map(JSONValue.string)),
        ]
        return optional.compactMapValues(\.self).merging(["isVideo": .bool(media.isVideo)]) { $1 }
    }
}

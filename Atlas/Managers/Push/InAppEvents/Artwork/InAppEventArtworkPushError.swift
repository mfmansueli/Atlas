//
//  InAppEventArtworkPushError.swift
//  Atlas
//

import Foundation

/// Why an event card or details page didn't reach App Store Connect.
enum InAppEventArtworkPushError: LocalizedError, Equatable {
    /// The transport can't send file parts (a DEBUG scene's).
    case cannotUpload
    /// The file left this Mac's Atlas folder.
    case fileMissing(fileName: String)
    /// Apple's processing said `FAILED`.
    case refused(fileName: String, details: String?)
    case timedOut(fileName: String)

    var errorDescription: String? {
        switch self {
        case .cannotUpload:
            String(localized: "This connection can’t push files.")
        case let .fileMissing(fileName):
            String(localized: "“\(fileName)” isn’t on this Mac anymore. Ask for the art again.")
        case let .refused(fileName, details):
            details.map { String(localized: "App Store Connect couldn’t process “\(fileName)”: \($0)", comment: "kind:error") }
                ?? String(localized: "App Store Connect couldn’t process “\(fileName)”.", comment: "kind:error")
        case let .timedOut(fileName):
            String(localized: "App Store Connect was still processing “\(fileName)”. Push again later to check it.")
        }
    }
}

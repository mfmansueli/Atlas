//
//  ArtworkWebError.swift
//  Atlas
//

import Foundation

/// Why an HTML page couldn't be rendered. A load's or script's reason
/// is WebKit's own text, shown after "Details:".
enum ArtworkWebError: LocalizedError, Equatable {
    case setupFailed
    case loadFailed(String)
    case scriptFailed(String)
    case snapshotFailed
    case tooLarge(Int)
    case timedOut
    /// WebKit failed twice in a row on the page.
    case rendererStopped

    /// Why a load ends when the page's process does.
    static let processEnded = String(localized: "the page’s process ended")

    var errorDescription: String? {
        switch self {
        case .setupFailed:
            String(localized: "The page renderer couldn’t be set up.")
        case let .loadFailed(reason):
            AppleErrorCopy(summary: String(localized: "The page didn’t load. Try again.", comment: "kind:error"), details: reason).text
        case let .scriptFailed(reason):
            AppleErrorCopy(summary: String(localized: "Atlas couldn’t fill in the page. Try again.", comment: "kind:error"), details: reason).text
        case .snapshotFailed:
            String(localized: "The page couldn’t be drawn.")
        case let .tooLarge(bytes):
            String(localized: "The page is \(bytes.formatted(.byteCount(style: .file))); keep it under \(AutopilotArtworkDesign.maximumBytes.formatted(.byteCount(style: .file))).")
        case .timedOut:
            String(localized: "The page took too long to load.")
        case .rendererStopped:
            String(localized: "The page renderer stopped twice. Send it again; if it stops, use fewer or smaller blurs and filters.")
        }
    }
}

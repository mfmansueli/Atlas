//
//  ArtworkLoopError.swift
//  Atlas
//

import Foundation

/// Why a header or search motion loop couldn't be made.
enum ArtworkLoopError: LocalizedError, Equatable {
    /// The movie writer failed; the reason is the system's own text,
    /// shown after "Details:".
    case writerFailed(String)
    case drawingFailed
    case layersFailed

    var errorDescription: String? {
        switch self {
        case let .writerFailed(reason):
            AppleErrorCopy(summary: String(localized: "The loop couldn’t be written. Try again.", comment: "kind:error"), details: reason).text
        case .drawingFailed: String(localized: "A frame of the loop couldn’t be drawn.")
        case .layersFailed: String(localized: "The artwork couldn’t be drawn for the loop.")
        }
    }
}

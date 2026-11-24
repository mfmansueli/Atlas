//
//  AppPreviewSetPushError.swift
//  Atlas
//

import Foundation

/// Why App Previews changed by hand didn't reach App Store Connect, beyond
/// what a product page's own App Previews share
/// (`ProductPageScreenshotsPushError`: no file uploads, Apple refused or
/// was still processing a video).
enum AppPreviewSetPushError: LocalizedError, Equatable {
    /// The video left this Mac's Atlas folder.
    case fileMissing(fileName: String)
    /// More than a set takes.
    case tooMany(count: Int)

    var errorDescription: String? {
        switch self {
        case let .fileMissing(fileName):
            String(localized: "“\(fileName)” isn’t on this Mac anymore. Choose the App Preview again.", comment: "kind:error")
        case let .tooMany(count):
            String(localized: "\(count) App Previews in one set. A set takes up to 3.", comment: "kind:error")
        }
    }
}

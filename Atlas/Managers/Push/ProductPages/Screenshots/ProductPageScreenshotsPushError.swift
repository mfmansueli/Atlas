//
//  ProductPageScreenshotsPushError.swift
//  Atlas
//

import Foundation

/// Why a custom product page's own screenshots didn't reach App Store
/// Connect.
enum ProductPageScreenshotsPushError: LocalizedError, Equatable {
    /// The transport can't send file parts (a DEBUG scene's).
    case cannotUpload
    /// The page made in Atlas isn't in App Store Connect: its own change
    /// didn't go out.
    case pageMissing(name: String)
    /// The screenshot left this Mac's Atlas folder.
    case fileMissing(fileName: String)
    /// Apple's processing said `FAILED`.
    case refused(fileName: String, details: String?)
    case timedOut(fileName: String)

    var errorDescription: String? {
        switch self {
        case .cannotUpload:
            String(localized: "This connection can’t push files.")
        case let .pageMissing(name):
            String(localized: "“\(name)” isn’t in App Store Connect yet. Push the page first, then its screenshots.")
        case let .fileMissing(fileName):
            String(localized: "“\(fileName)” isn’t on this Mac anymore. Make the page’s screenshots again.")
        case let .refused(fileName, details):
            details.map { String(localized: "App Store Connect couldn’t process “\(fileName)”: \($0)", comment: "kind:error") }
                ?? String(localized: "App Store Connect couldn’t process “\(fileName)”.", comment: "kind:error")
        case let .timedOut(fileName):
            String(localized: "App Store Connect was still processing “\(fileName)”. Push again later to check it.")
        }
    }
}

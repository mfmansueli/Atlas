//
//  ListingTransferError.swift
//  Atlas
//

import Foundation

/// Why an imported file couldn't be read at all. Problems with single
/// values are `ListingImportProblem`s instead.
enum ListingTransferError: LocalizedError, Hashable, Sendable {
    case unsupportedFileType(String)
    /// Not UTF-8 text.
    case notText
    /// A CSV without a "field" column.
    case missingFieldColumn
    /// Malformed XML or JSON, with the parser's detail if any.
    case unreadable(detail: String?)

    var errorDescription: String? {
        switch self {
        case let .unsupportedFileType(fileExtension):
            String(localized: "“.\(fileExtension)” files can’t be imported. Choose a CSV, XLIFF or JSON file.")
        case .notText:
            String(localized: "The file isn’t UTF-8 text.")
        case .missingFieldColumn:
            String(localized: "Add a “field” column with names like subtitle or whatsNew.")
        case let .unreadable(detail):
            // The parser's own words go in Details, never in the message.
            AppleErrorCopy(
                summary: String(localized: "The file couldn’t be read. Check that it’s valid XLIFF or JSON.", comment: "kind:error"),
                details: detail
            ).text
        }
    }
}

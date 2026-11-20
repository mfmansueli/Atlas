//
//  ProductPageSubmissionError.swift
//  Atlas
//

import Foundation

/// Why Cancel Submission couldn't take a page back from App Review.
enum ProductPageSubmissionError: LocalizedError, Hashable, Sendable {
    /// The page went to App Review with other items: cancelling would
    /// take them back too.
    case sharedSubmission
    /// No waiting submission has the page: App Review may have started.
    case notWaiting

    var errorDescription: String? {
        switch self {
        case .sharedSubmission:
            String(localized: "The page went to App Review with other items, so Atlas didn’t cancel it. Cancel it in App Store Connect, under App Review.")
        case .notWaiting:
            String(localized: "The page isn’t waiting for review any more. App Review may have started on it.")
        }
    }
}

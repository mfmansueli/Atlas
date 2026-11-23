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
            String(localized: "Not canceled: it went with other items. Cancel it in App Store Connect, under App Review.")
        case .notWaiting:
            String(localized: "No longer waiting for review. App Review may have started.")
        }
    }
}

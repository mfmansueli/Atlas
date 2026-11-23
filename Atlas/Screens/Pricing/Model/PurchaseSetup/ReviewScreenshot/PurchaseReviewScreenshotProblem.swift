//
//  PurchaseReviewScreenshotProblem.swift
//  Atlas
//

import Foundation

/// Why a file can't be a product's App Review screenshot.
enum PurchaseReviewScreenshotProblem: LocalizedError, Hashable, Sendable {
    /// Not a PNG or JPEG Atlas can read.
    case notAnImage(fileName: String)
    case tooSmall(PixelSize)

    var errorDescription: String? {
        switch self {
        case let .notAnImage(fileName):
            String(localized: "“\(fileName)” isn’t a PNG or JPEG image Atlas can read.")
        case let .tooSmall(size):
            String(localized: """
            The image is \(size.width) × \(size.height) pixels. Use a purchase screenshot at least \
            \(PurchaseReviewScreenshotFile.minimumSide) pixels per side.
            """)
        }
    }
}

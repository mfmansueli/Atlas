//
//  ProductPageTestFailure.swift
//  Atlas
//

import Foundation

/// Why a step of a test didn't go, worded for its row.
enum ProductPageTestFailure: Error, Hashable, Sendable {
    /// App Store Connect refused the artwork on the treatment's page: its
    /// placement type isn't one a treatment takes, maybe.
    case placementRefused(placementType: String, detail: String)
    /// No placement group takes the variant's size.
    case noMatchingGroup(placementType: String, pixelSize: PixelSize, accepted: [PixelSize])
    case file(detail: String)
    case processing(state: String, details: String?)
    case processingTimedOut
    case upload(detail: String)

    var text: String {
        copy.text
    }

    /// The sentence, with the system's own words kept for Details where the
    /// failure isn't Apple's or Atlas's.
    var copy: AppleErrorCopy {
        if case let .file(detail) = self {
            return AppleErrorCopy(summary: String(localized: "The variant file couldn’t be read. Try again.", comment: "kind:error"), details: detail)
        }
        return AppleErrorCopy(summary: sentence, details: nil)
    }

    private var sentence: String {
        switch self {
        case let .placementRefused(placementType, detail):
            String(localized: "App Store Connect didn’t take \(ExtrasPushKind.name(ofPlacementType: placementType)) on the test’s treatment (\(detail)).")
        case let .noMatchingGroup(placementType, pixelSize, accepted):
            ExtrasPushFailure.noMatchingGroup(placementType: placementType, pixelSize: pixelSize, isVideo: false, accepted: accepted).text
        case .file:
            String(localized: "The variant file couldn’t be read. Try again.", comment: "kind:error")
        case let .processing(state, details):
            String(localized: "Apple couldn’t process the variant (\(details ?? state)).")
        case .processingTimedOut:
            String(localized: "Apple is still processing the variant. Try again later.")
        case let .upload(detail):
            String(localized: "Couldn’t push the variant (\(detail)).")
        }
    }
}

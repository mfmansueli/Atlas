//
//  ExtrasPushFailure.swift
//  Atlas
//

import Foundation

/// Why one extra didn't go, worded for its progress row: what failed and
/// what that means for the App Store page.
enum ExtrasPushFailure: Error, Hashable, Sendable {
    /// The made file couldn't be read from this Mac.
    case file(detail: String)
    /// App Store Connect has no asset library for the app.
    case noLibrary(detail: String)
    /// No placement group of this type takes a file of this size.
    case noMatchingGroup(placementType: String, pixelSize: PixelSize, isVideo: Bool, accepted: [PixelSize])
    /// A part of the file didn't upload.
    case part(Int, count: Int, timedOut: Bool, detail: String)
    /// Apple couldn't process the file, with its reasons if it gave any.
    case processing(state: String, details: String?)
    /// Apple was still processing the file when the push stopped waiting.
    case processingTimedOut
    /// The device's App Preview group is full and this one replaces none
    /// of them.
    case previewsFull(group: String, limit: Int)
    /// The placement was refused after what was in its slot was taken off:
    /// `restored` says whether that came back.
    case placing(detail: String, restored: Bool)

    /// The row's red line.
    var text: String {
        switch self {
        case let .file(detail):
            return String(localized: "Couldn’t read the file (\(detail)). Nothing was pushed.")
        case let .noLibrary(detail):
            return String(localized: "App Store Connect has no asset library for this app (\(detail)). Nothing was pushed.")
        case let .noMatchingGroup(placementType, pixelSize, isVideo, accepted):
            let place = ExtrasPushKind.name(ofPlacementType: placementType)
            let file = isVideo ? String(localized: "a \(pixelSize.title) video") : String(localized: "a \(pixelSize.title) image")
            guard !accepted.isEmpty else { return String(localized: "App Store Connect doesn’t take \(file) for \(place). Nothing was pushed.") }
            let sizes = accepted.map(\.title).formatted(.list(type: .or))
            return String(localized: "\(place) takes \(sizes), not \(file). Nothing was pushed.")
        case let .part(part, count, timedOut, detail):
            if timedOut { return String(localized: "Part \(part) of \(count) timed out. Nothing was placed. Try again.") }
            return String(localized: "Part \(part) of \(count) failed (\(detail)). Nothing was placed. Try again.")
        case let .processing(state, details):
            let reason = details ?? state
            return String(localized: "Apple couldn’t process the file (\(reason)). Nothing was placed.")
        case .processingTimedOut:
            return String(localized: "The file is with Apple but still processing. Retry Failed places it once ready.")
        case let .previewsFull(group, limit):
            return String(
                localized: "\(group) is full at \(limit) App Previews. Nothing was pushed."
            )
        case let .placing(detail, restored):
            if restored { return String(localized: "Couldn’t place it (\(detail)). The old one was restored.") }
            return String(localized: "Couldn’t place it (\(detail)). The old one was removed and couldn’t be restored.")
        }
    }
}

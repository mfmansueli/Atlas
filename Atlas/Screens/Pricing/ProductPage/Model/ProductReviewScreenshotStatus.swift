//
//  ProductReviewScreenshotStatus.swift
//  Atlas
//

import Foundation

/// The Review Screenshot tab's status line (board 73), from where the
/// product's App Review screenshot is (`ReviewShotsCardState`): missing
/// (with a Screenshots capture to use, or not), being captured, a capture
/// ready for Accept, accepted and waiting in Review & Push, or in App Store
/// Connect.
enum ProductReviewScreenshotStatus: Equatable, Sendable {
    /// What App Store Connect has isn't read yet.
    case notRead
    case missing(hasCapture: Bool)
    /// In an assistant's run: being captured, or next.
    case capturing(client: String?)
    /// An assistant's capture waits for Accept on the product's card.
    case captureReady(client: String?)
    case accepted
    case processing
    case inAppStoreConnect
    /// Apple refused the last upload.
    case refused

    /// What the line's symbol and colour mean.
    enum Tone: Equatable, Sendable {
        /// Needs the person: missing, refused.
        case needsYou
        /// In App Store Connect.
        case done
        /// Waiting in Review & Push.
        case notPushed
        /// The assistant's: a run, or its capture.
        case assistant
        case neutral
    }

    static func make(_ state: ReviewShotsCardState) -> Self {
        switch state {
        case .unknown: .notRead
        case let .missing(capture): .missing(hasCapture: capture != nil)
        case .notCaptured: .missing(hasCapture: false)
        case .queued: .capturing(client: nil)
        case let .working(_, _, client, _): .capturing(client: client)
        case let .suggested(item): .captureReady(client: item.details?.client)
        case .accepted: .accepted
        case let .uploaded(remote): remote.isUploaded ? .inAppStoreConnect : .processing
        case .failed: .refused
        }
    }

    var text: String {
        switch self {
        case .notRead:
            String(localized: "Not read from App Store Connect yet.", comment: "kind:label")
        case .missing(hasCapture: false):
            String(localized: "Missing. Until it’s added, the product stays in Missing Metadata.", comment: "kind:label")
        case .missing(hasCapture: true):
            String(localized: "Missing. Screenshots already has a capture of the paywall.", comment: "kind:label")
        case let .capturing(client?):
            String(localized: "\(client) is capturing it.", comment: "kind:label")
        case .capturing(nil):
            String(localized: "It’s next in this run.", comment: "kind:label")
        case let .captureReady(client?):
            String(localized: "\(client) captured one. Accept it in the product list.", comment: "kind:label")
        case .captureReady(nil):
            String(localized: "The assistant captured one. Accept it in the product list.", comment: "kind:label")
        case .accepted:
            String(localized: "Accepted. It’s in Review & Push.", comment: "kind:label")
        case .processing:
            String(localized: "In App Store Connect. Apple is still processing it.", comment: "kind:label")
        case .inAppStoreConnect:
            String(localized: "In App Store Connect. Apple lets you replace it, not remove it.")
        case .refused:
            String(localized: "Apple refused the last screenshot. Choose another.")
        }
    }

    var tone: Tone {
        switch self {
        case .missing, .refused: .needsYou
        case .inAppStoreConnect: .done
        case .accepted: .notPushed
        case .capturing, .captureReady: .assistant
        case .notRead, .processing: .neutral
        }
    }
}

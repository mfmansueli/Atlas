//
//  PurchaseReviewScreenshotState.swift
//  Atlas
//

import Foundation

/// A product's App Review screenshot in App Store Connect: none, Apple
/// still processing it, there, or refused.
enum PurchaseReviewScreenshotState: Hashable, Sendable {
    case missing
    case processing(fileName: String)
    case uploaded(fileName: String, checksum: String?)
    case failed(fileName: String)

    /// `MISSING`, `PROCESSING`, `UPLOADED` or `FAILED`, for get_subscriptions.
    var code: String {
        switch self {
        case .missing: "MISSING"
        case .processing: "PROCESSING"
        case .uploaded: "UPLOADED"
        case .failed: "FAILED"
        }
    }

    var fileName: String? {
        switch self {
        case .missing: nil
        case let .processing(name), let .uploaded(name, _), let .failed(name): name
        }
    }

    /// Whether App Review has a screenshot to look at.
    var isUploaded: Bool {
        if case .uploaded = self { return true }
        return false
    }

    /// "Review screenshot missing", as a product card shows it.
    var title: String {
        switch self {
        case .missing: String(localized: "Review screenshot missing")
        case .processing: String(localized: "Review screenshot processing")
        case .uploaded: String(localized: "Review screenshot uploaded")
        case .failed: String(localized: "Review screenshot refused")
        }
    }

    /// The state in a screenshot resource's attributes.
    init(resource: [String: Any]?) {
        guard let resource, let attributes = resource["attributes"] as? [String: Any] else {
            self = .missing
            return
        }
        let name = attributes["fileName"] as? String ?? ""
        let state = (attributes["assetDeliveryState"] as? [String: Any])?["state"] as? String
        switch state {
        case "COMPLETE": self = .uploaded(fileName: name, checksum: attributes["sourceFileChecksum"] as? String)
        case "FAILED": self = .failed(fileName: name)
        default: self = .processing(fileName: name)
        }
    }
}

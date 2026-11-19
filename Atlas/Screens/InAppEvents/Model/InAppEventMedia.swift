//
//  InAppEventMedia.swift
//  Atlas
//

import Foundation

/// An image or video of an event in one language: the card (16:9, shown in
/// search, Today and on the product page) or the details page's top (9:16).
struct InAppEventMedia: Hashable, Sendable {
    enum Kind: String, CaseIterable, Hashable, Sendable, Codable {
        case card = "EVENT_CARD"
        case details = "EVENT_DETAILS_PAGE"

        var title: String {
            switch self {
            case .card: String(localized: "Event card")
            case .details: String(localized: "Event details")
            }
        }

        /// "card" or "details page", inside a sentence.
        var name: String {
            switch self {
            case .card: String(localized: "event card")
            case .details: String(localized: "details page")
            }
        }

        /// "16:9" or "9:16".
        var ratioTitle: String {
            switch self {
            case .card: "16:9"
            case .details: "9:16"
            }
        }

        /// `card` or `details`, as MCP tools name it.
        var mcpValue: String {
            switch self {
            case .card: "card"
            case .details: "details"
            }
        }

        init?(mcpValue: String) {
            guard let kind = Self.allCases.first(where: { $0.mcpValue == mcpValue.lowercased() || $0.rawValue == mcpValue.uppercased() }) else {
                return nil
            }
            self = kind
        }

        /// "16:9 · shown in search, Today and on the product page".
        var detail: String {
            switch self {
            case .card: String(localized: "16:9 · shown in search, Today and on the product page")
            case .details: String(localized: "9:16 · the top of the event page")
            }
        }
    }

    var kind: Kind
    var isVideo = false
    var width: Int?
    var height: Int?
    /// The image at a size Atlas can show; nil for a video or
    /// while Apple processes it.
    var imageURL: URL?
    /// The file's name and size as it was uploaded, when Apple says
    /// (Atlas sends the name its file has on this Mac).
    var fileName: String?
    var fileSize: Int?
    /// A video's poster frame, "00:00:02:00".
    var previewFrameTimeCode: String?
    /// Apple's processing: `COMPLETE`, `PROCESSING`, `FAILED`…
    var state: String?
    /// What Apple said went wrong, when it failed.
    var stateErrors: [String] = []

    /// "1920 × 1080", when Apple says.
    var sizeText: String? {
        guard let width, let height else { return nil }
        return "\(width) × \(height)"
    }
}

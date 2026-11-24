//
//  NominationDevice.swift
//  Atlas
//

import Foundation

/// Where people can use what's nominated (`deviceFamilies`), in the order
/// the nomination lists them.
enum NominationDevice: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case iPhone = "IPHONE"
    case iPad = "IPAD"
    case mac = "MAC"
    case appleWatch = "APPLE_WATCH"
    case appleTV = "APPLE_TV"
    case vision = "VISION"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iPhone: "iPhone"
        case .iPad: "iPad"
        case .mac: "Mac"
        case .appleWatch: "Apple Watch"
        case .appleTV: "Apple TV"
        case .vision: "Apple Vision Pro"
        }
    }

    /// "iPhone · iPad", in this order; "No devices yet" for none.
    static func list(_ devices: [NominationDevice]) -> String {
        let shown = allCases.filter(devices.contains)
        guard !shown.isEmpty else { return String(localized: "No devices yet", comment: "kind:empty-state") }
        return shown.map(\.title).joined(separator: " · ")
    }
}

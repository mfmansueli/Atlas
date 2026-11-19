//
//  EventArtworkStep.swift
//  Atlas
//

import Foundation

/// The four steps of making an event's artwork (board 47): the person's
/// brief, Claude making three concepts, choosing one, and checking
/// it under the App Store's text.
enum EventArtworkStep: String, Codable, CaseIterable, Hashable, Sendable {
    case brief
    case making
    case choose
    case check

    var title: String {
        switch self {
        case .brief: String(localized: "Brief")
        case .making: String(localized: "Making")
        case .choose: String(localized: "Choose")
        case .check: String(localized: "Check")
        }
    }

    /// 1–4, as the steps bar numbers them.
    var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
}

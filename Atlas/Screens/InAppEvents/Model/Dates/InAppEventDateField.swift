//
//  InAppEventDateField.swift
//  Atlas
//

import Foundation

/// One of an event's three dates, named as `territorySchedules` names it:
/// from when its card shows on the App Store, when it starts and when it
/// ends.
enum InAppEventDateField: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case publishStart
    case eventStart
    case eventEnd

    var id: String { rawValue }

    /// "Shows from", "Starts", "Ends": the Details card's rows.
    var title: String {
        switch self {
        case .publishStart: String(localized: "Shows from")
        case .eventStart: String(localized: "Starts")
        case .eventEnd: String(localized: "Ends")
        }
    }
}

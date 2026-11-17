//
//  TraderDetailField.swift
//  Atlas
//

import Foundation

/// One of a trader's details, in the order the page lists them.
enum TraderDetailField: String, CaseIterable, Identifiable, Hashable, Sendable {
    case name
    case address
    case phone
    case email

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: String(localized: "Name")
        case .address: String(localized: "Address")
        case .phone: String(localized: "Phone")
        case .email: String(localized: "Email")
        }
    }
}

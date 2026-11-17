//
//  TraderDetails.swift
//  Atlas
//

import Foundation

/// What a trader shows on the app's page in the EU.
struct TraderDetails: Hashable, Codable, Sendable {
    var name = ""
    var address = ""
    var phone = ""
    var email = ""

    subscript(field: TraderDetailField) -> String {
        get {
            switch field {
            case .name: name
            case .address: address
            case .phone: phone
            case .email: email
            }
        }
        set {
            switch field {
            case .name: name = newValue
            case .address: address = newValue
            case .phone: phone = newValue
            case .email: email = newValue
            }
        }
    }

    /// The details that are filled in, in the page's order.
    var filled: [String] {
        TraderDetailField.allCases.map { self[$0].trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// One line for the preview: "Northpier Studio Ltd · 14 Harbour Road…".
    var summary: String { filled.joined(separator: " · ") }

    /// One detail per line, for the pasteboard.
    var pasteboardText: String {
        TraderDetailField.allCases
            .map { "\($0.title): \(self[$0].trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n")
    }
}

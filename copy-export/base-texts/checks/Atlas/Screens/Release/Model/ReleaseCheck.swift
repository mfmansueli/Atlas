//
//  ReleaseCheck.swift
//  Atlas
//

import Foundation

/// One line of what goes to App Review, on the version card: there and
/// fine, or what's missing, with a button when something can be done.
struct ReleaseCheck: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case build
        case whatsNew
        case changes
        case event
        case reviewInformation
    }

    var kind: Kind
    var isOK: Bool
    var title: String
    var detail: String
    /// "Review" or "Open".
    var buttonTitle: String?
    /// The event the button opens.
    var eventID: InAppEvent.ID?

    var id: String { kind.rawValue + (eventID ?? "") }
}

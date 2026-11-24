//
//  EventArtworkConceptCheck.swift
//  Atlas
//

import Foundation

/// One line of the Check step: "Nothing important under the text", and
/// what was found. Not OK is a warning: the person may still use the art.
struct EventArtworkConceptCheck: Codable, Hashable, Sendable {
    var title: String
    var detail: String
    var isOK: Bool
}

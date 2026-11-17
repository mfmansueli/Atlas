//
//  InAppEventTextSuggestion.swift
//  Atlas
//

import Foundation

/// One language of an event, suggested by an assistant: all three texts,
/// with why they read this way ("In Brazil December is summer…"). It waits
/// for Accept; accepted, the texts wait in Review & Push.
struct InAppEventTextSuggestion: Identifiable, Hashable, Codable, Sendable {
    var eventID: InAppEvent.ID
    /// An App Store locale code, e.g. `pt-BR`.
    var locale: String
    var name: String
    var shortDescription: String
    var longDescription: String
    var why: String
    /// Who suggested it, e.g. "Claude Code".
    var source: String
    var date: Date

    var id: String { "\(eventID).\(locale)" }

    func text(_ field: InAppEventField) -> String {
        switch field {
        case .name: name
        case .shortDescription: shortDescription
        case .longDescription: longDescription
        }
    }

    /// The first field over Apple's limit, with its length.
    var overLimit: (field: InAppEventField, count: Int)? {
        InAppEventField.allCases.lazy.map { ($0, text($0).count) }.first { $0.1 > $0.0.limit }.map { (field: $0.0, count: $0.1) }
    }
}

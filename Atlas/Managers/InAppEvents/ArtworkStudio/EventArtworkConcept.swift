//
//  EventArtworkConcept.swift
//  Atlas
//

import Foundation

/// One concept for an event's artwork: the card and the details image as
/// a matching pair from one composition (only the details image when the
/// card stays), Claude's pages for them, the stills Atlas rendered
/// and checked, and why it was drawn this way. Files the person chose
/// make a concept too, so they go through the same Check step.
struct EventArtworkConcept: Codable, Hashable, Sendable, Identifiable {
    enum Source: String, Codable, Hashable, Sendable {
        case claudeDesign
        case files
    }

    var id: String
    var name: String
    var why: String
    /// Claude's own pick of the three.
    var isPick = false
    var source: Source = .claudeDesign
    /// Who designed it: "Claude Code".
    var client: String
    /// The HTML pages, by kind; none for files.
    var pages: [InAppEventMedia.Kind: String] = [:]
    var stills: [EventArtworkImage]
    /// The moving versions, rendered when the concept is used.
    var videos: [EventArtworkImage] = []
    var checks: [EventArtworkConceptCheck] = []
    var arrivedAt: Date
    /// Claude redrew it the way the person asked: "Updated".
    var revisedAt: Date?

    var kinds: [InAppEventMedia.Kind] {
        InAppEventMedia.Kind.allCases.filter { kind in stills.contains { $0.kind == kind } }
    }

    /// The still of `kind` shown in `locale`: that language's own, else
    /// the one for every language, else any.
    func still(_ kind: InAppEventMedia.Kind, locale: String? = nil) -> EventArtworkImage? {
        let ofKind = stills.filter { $0.kind == kind }
        return ofKind.first { $0.locale == locale && locale != nil } ?? ofKind.first { $0.locale == nil } ?? ofKind.first
    }

    /// The moving version of `kind` in `locale`, the same way.
    func video(_ kind: InAppEventMedia.Kind, locale: String? = nil) -> EventArtworkImage? {
        let ofKind = videos.filter { $0.kind == kind }
        return ofKind.first { $0.locale == locale && locale != nil } ?? ofKind.first { $0.locale == nil } ?? ofKind.first
    }

    var isMadeByClaudeDesign: Bool { source == .claudeDesign }
}

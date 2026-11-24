//
//  NominationBuiltInSuggestion.swift
//  Atlas
//

import Foundation

/// A suggestion Atlas makes itself for a draft's empty field, from what it
/// knows (`NominationContext`), with its one-line why: the type from the
/// version and the events, the description from What's New and the linked
/// events. Shown in purple; Accept fills the field, nothing is queued.
struct NominationBuiltInSuggestion: Identifiable, Hashable, Sendable {
    var field: NominationField
    var nominationID: String
    /// The suggested type, for `field == .type`.
    var type: NominationType?
    /// The suggested text, for `field == .description`.
    var text: String = ""
    var why: String
    var confidence: HowSure

    /// What a dismissal is kept under.
    var id: String { "\(nominationID).\(field.rawValue)" }

    /// The suggestions for `nomination`'s empty type and description.
    static func suggestions(for nomination: Nomination, context: NominationContext) -> [NominationBuiltInSuggestion] {
        guard nomination.isEditable else { return [] }
        var suggestions: [NominationBuiltInSuggestion] = []
        if nomination.content.type == nil, let type = suggestedType(for: nomination, context: context) {
            suggestions.append(type)
        }
        if nomination.content.trimmedDescription.isEmpty, let description = suggestedDescription(for: nomination, context: context) {
            suggestions.append(description)
        }
        return suggestions
    }

    /// A first version is an App Launch; an event linked (or coming, with no
    /// version in preparation) is New Content; a version with What's New is
    /// App Enhancements.
    static func suggestedType(for nomination: Nomination, context: NominationContext) -> NominationBuiltInSuggestion? {
        let linked = context.events.filter { nomination.content.eventIDs.contains($0.id) }
        if let version = context.version, version.isFirstVersion {
            let why = String(localized: "Version \(version.versionString) is the app’s first: nothing is on the App Store yet.", comment: "kind:suggestion-why")
            return NominationBuiltInSuggestion(field: .type, nominationID: nomination.id, type: .appLaunch, why: why, confidence: .sure)
        }
        if let event = linked.first ?? (context.version == nil ? context.events.first(where: { !$0.isOver }) : nil) {
            let why = String(localized: "\(event.name) is new content for people who already have the app.", comment: "kind:suggestion-why")
            return NominationBuiltInSuggestion(field: .type, nominationID: nomination.id, type: .newContent, why: why, confidence: .fairlySure)
        }
        if let version = context.version, !version.whatsNew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let why = String(localized: "Version \(version.versionString) adds new features to an app already on the App Store.", comment: "kind:suggestion-why")
            return NominationBuiltInSuggestion(field: .type, nominationID: nomination.id, type: .appEnhancements, why: why, confidence: .sure)
        }
        return nil
    }

    /// What's New's lines as sentences, then each linked event's name, start
    /// and short description.
    static func suggestedDescription(for nomination: Nomination, context: NominationContext) -> NominationBuiltInSuggestion? {
        let linked = context.events.filter { nomination.content.eventIDs.contains($0.id) }
        var sentences: [String] = []
        var sources: [String] = []
        if let version = context.version {
            let lines = version.whatsNew.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "•-–* ").union(.whitespaces)) }
                .filter { !$0.isEmpty }
                .prefix(3)
            if !lines.isEmpty {
                sentences += lines.map { $0.hasSuffix(".") || $0.hasSuffix("!") ? String($0.dropLast()) + "." : $0 + "." }
                sources.append(String(localized: "\(version.versionString)’s What’s New", comment: "kind:other"))
            }
        }
        for event in linked {
            let when = event.start.map { String(localized: ", from \($0.formatted(.dateTime.month(.abbreviated).day()))", comment: "kind:other") } ?? ""
            let line = event.shortDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            sentences.append(line.isEmpty ? "\(event.name)\(when)." : "\(event.name)\(when): \(line.hasSuffix(".") ? line : line + ".")")
            sources.append(event.name)
        }
        guard !sentences.isEmpty else { return nil }
        let why = String(localized: "Written from \(sources.formatted(.list(type: .and))).", comment: "kind:suggestion-why")
        return NominationBuiltInSuggestion(
            field: .description, nominationID: nomination.id, text: sentences.joined(separator: " "), why: why, confidence: .fairlySure
        )
    }

    /// The links Atlas knows that the nomination doesn't have yet.
    static func knownLinks(for nomination: Nomination, context: NominationContext) -> [NominationContext.KnownLink] {
        let have = Set(nomination.content.materials.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        return context.links.filter { !have.contains($0.url) && !$0.url.isEmpty }
    }
}

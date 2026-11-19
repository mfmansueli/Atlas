//
//  EventArtworkRun.swift
//  Atlas
//

import Foundation

/// Making one event's artwork with Claude (board 47): the brief and
/// options the person chose, the concepts as they arrive, the one picked,
/// a change asked for, and the concept used. It lives on after the sheet
/// is hidden, so Claude Code keeps going and the event shows its progress.
struct EventArtworkRun: Codable, Hashable, Sendable, Identifiable {
    /// One run per app and event.
    struct Key: Codable, Hashable, Sendable {
        var appID: StoreApp.ID
        var eventID: InAppEvent.ID
    }

    var appID: StoreApp.ID
    var eventID: InAppEvent.ID
    var eventName: String
    var step: EventArtworkStep = .brief
    /// What the art should show, in the person's words (written for them
    /// from the event's texts to start with).
    var brief: String
    /// A capture of the screen the event is about goes to Claude.
    var usesCapture = true
    /// The event's name is drawn into the art: a pair per language.
    var wordsInArt = false
    /// A moving version of each image too.
    var makesMotion = false
    var style: EventArtworkStyle
    /// The event's languages, primary first, when the run started.
    var locales: [String]
    var concepts: [EventArtworkConcept] = []
    /// How many concepts a run makes.
    var expectedCount = 3
    var pickedID: EventArtworkConcept.ID?
    /// The concept being redrawn, and what the person asked for.
    var revisingID: EventArtworkConcept.ID?
    var revisionRequest: String?
    /// Make Them Move: the concepts Claude is giving motion, its
    /// drawing kept. Nil (not empty) when none, so runs saved before it
    /// still decode.
    var animatingIDs: [EventArtworkConcept.ID]?
    /// The person hasn't seen the run since it started: the menu bar's dot
    /// and the notification when the concepts are ready.
    var isHidden = false
    var startedAt: Date?
    /// The Claude Code run Atlas started for it; nil when the prompt was
    /// copied to paste.
    var claudeRunID: UUID?
    /// The concept whose images wait in Review & Push, and when it was
    /// used: a later change to it can be used again.
    var usedConceptID: EventArtworkConcept.ID?
    var usedAt: Date?
    var queuedChangeIDs: [PendingChange.ID] = []

    var id: Key { key }
    var key: Key { Key(appID: appID, eventID: eventID) }
    var primaryLocale: String { locales.first ?? "en-US" }

    var picked: EventArtworkConcept? {
        concepts.first { $0.id == pickedID } ?? concepts.first { $0.isPick } ?? concepts.first
    }

    var used: EventArtworkConcept? {
        concepts.first { $0.id == usedConceptID }
    }

    var revising: EventArtworkConcept? {
        concepts.first { $0.id == revisingID }
    }

    /// Claude is drawing new concepts: not a change to one, not
    /// motion for the ones there.
    var isDrawing: Bool { step == .making && revisingID == nil && !isAnimating }

    /// The concepts are in and none is being drawn: the person chooses.
    var isReady: Bool { (step == .choose || step == .check) && !concepts.isEmpty }

    /// `concept` can go to Review & Push: it isn't the one there, or it
    /// changed since it was used.
    func canUse(_ concept: EventArtworkConcept) -> Bool {
        guard concept.id != revisingID else { return false }
        guard concept.id == usedConceptID else { return true }
        return (concept.revisedAt ?? .distantPast) > (usedAt ?? .distantPast)
    }

    /// Concepts of this run's own making (files the person chose aren't).
    var designedCount: Int { concepts.count { $0.isMadeByClaudeDesign } }

    var isAnimating: Bool { !(animatingIDs ?? []).isEmpty }

    /// The concepts still waiting for their motion.
    var animating: [EventArtworkConcept] {
        let ids = animatingIDs ?? []
        return concepts.filter { ids.contains($0.id) }
    }

    /// Claude's concepts made without motion: Make Them Move
    /// animates them as they are.
    var stillConcepts: [EventArtworkConcept] {
        concepts.filter { $0.isMadeByClaudeDesign && $0.videos.isEmpty && !$0.pages.isEmpty }
    }

    var canAddMotion: Bool { revisingID == nil && !isAnimating && !stillConcepts.isEmpty }

    /// Every concept has arrived.
    var isComplete: Bool { designedCount >= expectedCount }

    /// The id the next concept gets: a, b, c….
    var nextConceptID: String {
        let taken = Set(concepts.map(\.id))
        let letters = "abcdefghijklmnopqrstuvwxyz".map(String.init)
        return letters.first { !taken.contains($0) } ?? UUID().uuidString
    }

    /// The languages the art is rendered in: each with words in the art,
    /// else the primary one for all.
    var renderedLocales: [String] { wordsInArt ? locales : [primaryLocale] }
}

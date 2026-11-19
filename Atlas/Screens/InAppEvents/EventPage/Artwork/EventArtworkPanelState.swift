//
//  EventArtworkPanelState.swift
//  Atlas
//

import Foundation

/// What the event's Artwork panel shows (boards 40 and 47): Claude
/// drawing, the concepts to choose from, the one used, an image missing,
/// or the images the event has; its status line, the rows or the pair,
/// and which buttons it offers.
struct EventArtworkPanelState: Hashable {
    enum Phase: Hashable {
        case drawing(ready: Int, total: Int)
        /// Make Them Move: motion for the concepts there.
        case animating(done: Int, total: Int)
        case ready(count: Int)
        /// Change…: the concepts are back, one is used.
        case changing
        case used(name: String, kinds: Int, moves: Bool)
        case missing([InAppEventMedia.Kind])
        case complete
    }

    enum Tone: Hashable {
        case normal
        case suggestion
        case warning
    }

    /// One concept in the rows, or a place for one still being drawn.
    struct Row: Hashable, Identifiable {
        enum State: Hashable {
            case ready
            case drawing
            case waiting
            case redrawing
            case animating
        }

        enum Tag: Hashable {
            case inUse
            case updated
            case pick
        }

        var id: String
        var concept: EventArtworkConcept?
        var state: State
        var tag: Tag?
        var isPreviewed: Bool

        var isBusy: Bool { state != .ready }
        /// Drawing or waiting: nothing to click yet.
        var isDisabled: Bool { state == .drawing || state == .waiting }
        /// The view button: ready, not being redrawn.
        var canView: Bool { concept != nil && (state == .ready || state == .animating) }

        var name: String {
            concept?.name ?? String(localized: "Concept \(id)")
        }

        var why: String {
            switch state {
            case .drawing: String(localized: "Drawing…")
            case .waiting: String(localized: "Waiting")
            case .redrawing: String(localized: "Claude is changing it…")
            case .animating: String(localized: "Adding motion…")
            case .ready:
                if let concept, !concept.why.isEmpty {
                    concept.why
                } else {
                    String(localized: "Your card and details image.")
                }
            }
        }

        var tagTitle: String? {
            switch tag {
            case .inUse: String(localized: "In use")
            case .updated: String(localized: "Updated")
            case .pick: String(localized: "Claude’s pick")
            case nil: nil
            }
        }
    }

    var phase: Phase
    var rows: [Row] = []
    var languages = 1
    var canEdit = true
    var isOver = false
    /// The concept being redrawn, when there is one.
    var revisingName: String?
    var usedName: String?
    var previewID: EventArtworkConcept.ID?
    var conceptCount = 0
    /// The preview's concept can go to Review & Push.
    var previewCanBeUsed = false
    var runCanAddMotion = false
    var usedMadeByClaudeDesign = false

    // MARK: - Making

    static func make(
        run: EventArtworkRun?, isChanging: Bool, usedIsQueued: Bool, missing: [InAppEventMedia.Kind], languages: Int, canEdit: Bool,
        isOver: Bool, preview: EventArtworkConcept?
    ) -> Self {
        let phase = phase(run: run, isChanging: isChanging, usedIsQueued: usedIsQueued, missing: missing)
        var state = EventArtworkPanelState(phase: phase, languages: languages, canEdit: canEdit, isOver: isOver)
        guard let run else { return state }
        state.revisingName = run.revising?.name
        state.usedName = run.used?.name
        state.usedMadeByClaudeDesign = run.used?.isMadeByClaudeDesign ?? false
        state.previewID = preview?.id
        state.conceptCount = run.concepts.count
        state.previewCanBeUsed = preview.map(run.canUse) ?? false
        state.runCanAddMotion = run.canAddMotion && run.usedConceptID == nil
        if state.isRows { state.rows = rows(of: run, previewID: preview?.id, usedIsCurrent: usedIsQueued || missing.isEmpty) }
        return state
    }

    private static func phase(run: EventArtworkRun?, isChanging: Bool, usedIsQueued: Bool, missing: [InAppEventMedia.Kind]) -> Phase {
        guard let run, run.step != .brief || !run.concepts.isEmpty else { return missing.isEmpty ? .complete : .missing(missing) }
        if run.isDrawing { return .drawing(ready: run.designedCount, total: max(run.expectedCount, run.designedCount)) }
        if run.isAnimating {
            let total = run.concepts.count { $0.isMadeByClaudeDesign }
            return .animating(done: total - run.animating.count, total: max(1, total))
        }
        guard !run.concepts.isEmpty else { return missing.isEmpty ? .complete : .missing(missing) }
        if let used = run.used, usedIsQueued || missing.isEmpty {
            if isChanging { return .changing }
            return usedIsQueued ? .used(name: used.name, kinds: used.kinds.count, moves: !used.videos.isEmpty) : .complete
        }
        return .ready(count: run.concepts.count)
    }

    private static func rows(of run: EventArtworkRun, previewID: EventArtworkConcept.ID?, usedIsCurrent: Bool) -> [Row] {
        var rows = run.concepts.map { concept in
            let state: Row.State = if concept.id == run.revisingID {
                .redrawing
            } else if (run.animatingIDs ?? []).contains(concept.id) {
                .animating
            } else {
                .ready
            }
            let tag: Row.Tag? = if concept.id == run.usedConceptID, usedIsCurrent {
                .inUse
            } else if concept.revisedAt != nil {
                .updated
            } else if concept.isPick {
                .pick
            } else {
                nil
            }
            return Row(id: concept.id, concept: concept, state: state, tag: tag, isPreviewed: concept.id == previewID)
        }
        if run.isDrawing {
            let left = max(0, run.expectedCount - run.designedCount)
            for index in 0..<left {
                let number = run.designedCount + index + 1
                rows.append(Row(id: "\(number)", concept: nil, state: index == 0 ? .drawing : .waiting, tag: nil, isPreviewed: false))
            }
        }
        return rows
    }

    // MARK: - What it says

    /// The rows of concepts, rather than the pair.
    var isRows: Bool {
        switch phase {
        case .drawing, .animating, .ready, .changing: true
        case .used, .missing, .complete: false
        }
    }

    var isDrawing: Bool {
        switch phase {
        case .drawing, .animating: true
        default: false
        }
    }

    /// The "C Claude" chip by the heading.
    var isByClaudeDesign: Bool {
        switch phase {
        case .drawing, .animating, .ready, .changing: true
        case .used: usedMadeByClaudeDesign
        case .missing, .complete: false
        }
    }

    var line: String {
        if let revisingName, !isRows { return String(localized: "Claude is changing “\(revisingName)”") }
        switch phase {
        case let .drawing(ready, total): return String(localized: "Claude is drawing · \(ready) of \(total) ready")
        case let .animating(done, total): return String(localized: "Claude is adding motion · \(done) of \(total) moving")
        case let .ready(count):
            return count == 1 ? String(localized: "1 concept is ready") : String(localized: "\(count) concepts are ready")
        case .changing: return String(localized: "Choose another concept")
        case let .used(name, _, _): return "“\(name)”"
        case let .missing(kinds):
            if kinds == [.card] { return String(localized: "Event card missing") }
            if kinds == [.details] { return String(localized: "Event details image missing") }
            return String(localized: "Event card and event details missing")
        case .complete: return String(localized: "Event card and event details")
        }
    }

    var tone: Tone {
        switch phase {
        case .ready: .suggestion
        case .missing: .warning
        default: .normal
        }
    }

    var detail: String {
        if revisingName != nil, !isRows {
            return String(localized: "Review & Push keeps the images you used until you use the changed ones.")
        }
        switch phase {
        case .drawing: return String(localized: "Each concept shows up here as it’s done. You can open the ones that are ready.")
        case .animating:
            return String(localized: "Each concept keeps its drawing and gets a \(AutopilotArtworkMotion.loopSeconds)-second loop. You can open the ones that are ready.")
        case .ready, .changing: return String(localized: "Click one to see it on the App Store card. Nothing is chosen until you use one.")
        case let .used(_, kinds, moves):
            if kinds < 2 { return String(localized: "Event details, for all \(languages) languages · in Review & Push") }
            return moves
                ? String(localized: "Event card and event details, a matching pair for all \(languages) languages, each with a moving version · in Review & Push")
                : String(localized: "Event card and event details, a matching pair for all \(languages) languages · in Review & Push")
        case .missing: return String(localized: "Needed to submit. Claude can make a matching pair from the event’s text.")
        case .complete:
            return isOver ? String(localized: "As they were on the App Store.") : String(localized: "1920 × 1080 and 1080 × 1920 · the same pair in every language")
        }
    }

    /// 8% with none ready, then a share for each one: 39% and 69% of three.
    var progress: Double {
        switch phase {
        case let .drawing(ready, total): 0.08 + 0.92 * Double(ready) / Double(max(1, total))
        case let .animating(done, total): 0.08 + 0.92 * Double(done) / Double(max(1, total))
        default: 0
        }
    }

    // MARK: - Buttons

    var showsMake: Bool { canEdit && phase.isMissing }
    var showsChooseFiles: Bool { canEdit && phase.isMissing }
    var showsStop: Bool { isDrawing || (revisingName != nil && canEdit) }
    /// View Full Size: a concept in the preview, or images to show.
    var showsView: Bool {
        switch phase {
        case .used, .complete: true
        case .drawing, .animating, .ready, .changing: previewID != nil
        case .missing: false
        }
    }

    var showsChange: Bool {
        guard canEdit, conceptCount > 1, revisingName == nil else { return false }
        switch phase {
        case .used, .complete: return true
        default: return false
        }
    }

    var showsKeepCurrent: Bool { phase == .changing }

    var showsUse: Bool { canEdit && isRows && !isDrawing && previewCanBeUsed }

    /// Make Them Move: the concepts were drawn still, none used yet.
    var showsAddMotion: Bool {
        guard canEdit, runCanAddMotion, revisingName == nil else { return false }
        if case .ready = phase { return true }
        return false
    }

    /// Make the Artwork… or Choose Files… for an event whose images are
    /// all there, in a menu.
    var showsReplace: Bool {
        guard canEdit, !isOver, !showsChange, revisingName == nil else { return false }
        switch phase {
        case .used, .complete: return true
        default: return false
        }
    }

    /// Short, for the accessibility id: events.art.panel.<id>.
    var id: String {
        switch phase {
        case .drawing: "drawing"
        case .animating: "animating"
        case .ready: "ready"
        case .changing: "changing"
        case .used: "used"
        case .missing: "missing"
        case .complete: "complete"
        }
    }
}

private extension EventArtworkPanelState.Phase {
    var isMissing: Bool {
        if case .missing = self { return true }
        return false
    }
}

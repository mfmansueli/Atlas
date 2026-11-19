//
//  EventArtworkFlow.swift
//  Atlas
//

import Foundation
import Observation

/// One event's artwork (boards 40 and 47): the Brief in the sheet before
/// anything starts, then the run in `EventArtworkStudio` on the event's
/// page as Claude draws it: the concept in the preview, changing
/// the one used, the full-size viewer, Ask for Changes and Use This
/// Artwork. Starting Claude Code, stopping it and copying a prompt come in
/// from the section, so tests and DEBUG scenes run without it.
@MainActor
@Observable
final class EventArtworkFlow {
    let app: StoreApp
    let event: InAppEvent
    let studio: EventArtworkStudio
    let queue: ChangeQueue
    /// A design project is connected to the app: a new look is offered.
    let hasDesignSystem: Bool

    /// The run before Make the Artwork.
    private(set) var draft: EventArtworkRun
    /// Change… on the event: the concepts are back to choose another one.
    var isChanging = false
    /// Atlas couldn't start Claude Code here, so the prompt was copied.
    var copiedPrompt: String?
    var isWorking = false
    var problem: String?
    /// The full-size viewer over the window.
    var viewer: EventArtworkViewer?

    /// Starts Claude Code; nil when it can't start here.
    @ObservationIgnored var launch: (ClaudeCodeRunPurpose, String) async -> UUID? = { _, _ in nil }
    @ObservationIgnored var stopClaude: (UUID) -> Void = { _ in }
    @ObservationIgnored var copy: (String) -> Void = { _ in }
    /// A toast for the section, with Undo when it's given.
    @ObservationIgnored var onToast: (ToastMessage, InAppEventsUndo?) -> Void = { _, _ in }
    @ObservationIgnored var directory = InAppEventArtworkFiles.directory
    @ObservationIgnored var now: () -> Date = { .now }

    init(app: StoreApp, event: InAppEvent, studio: EventArtworkStudio, queue: ChangeQueue, hasDesignSystem: Bool) {
        self.app = app
        self.event = event
        self.studio = studio
        self.queue = queue
        self.hasDesignSystem = hasDesignSystem
        let locales = Self.locales(of: event)
        draft = EventArtworkRun(
            appID: app.id, eventID: event.id, eventName: event.referenceName, brief: EventArtworkBrief.written(for: event),
            style: Self.defaultStyle(event: event, hasDesignSystem: hasDesignSystem), locales: locales
        )
    }

    var key: EventArtworkRun.Key { EventArtworkRun.Key(appID: app.id, eventID: event.id) }
    var isStarted: Bool { studio.run(appID: app.id, eventID: event.id) != nil }
    var run: EventArtworkRun { studio.run(appID: app.id, eventID: event.id) ?? draft }
    var step: EventArtworkStep { run.step }
    var builder: InAppEventChangeBuilder { InAppEventChangeBuilder(appID: app.id) }

    /// The event's languages, primary first.
    static func locales(of event: InAppEvent) -> [String] {
        let codes = event.localizations.map(\.locale)
        guard let primary = event.primaryLocale ?? codes.first else { return ["en-US"] }
        return [primary] + codes.filter { $0 != primary }
    }

    /// A new look with a design project (Recommended), a template without
    /// one. Extending the card is the person's choice.
    static func defaultStyle(event _: InAppEvent, hasDesignSystem: Bool) -> EventArtworkStyle {
        hasDesignSystem ? .newLook : .template
    }

    /// The styles offered: no extending without a card, no new look
    /// without a design project.
    func isOffered(_ style: EventArtworkStyle) -> Bool {
        switch style {
        case .newLook: hasDesignSystem
        case .template: true
        case .extendCard: event.media(.card) != nil
        }
    }

    // MARK: - Brief

    /// Changes the brief's choices, on the run once it's in the studio.
    func edit(_ change: (inout EventArtworkRun) -> Void) {
        if isStarted { studio.update(key, change) } else { change(&draft) }
    }

    var minutes: Int { EventArtworkBrief.minutes(style: run.style, wordsInArt: run.wordsInArt, makesMotion: run.makesMotion) }

    var summary: String {
        EventArtworkBrief.summary(style: run.style, wordsInArt: run.wordsInArt, makesMotion: run.makesMotion, appName: app.name)
    }

    var canMake: Bool { !run.brief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Make the Artwork: the run goes to the studio, the sheet closes and
    /// Claude Code starts.
    func make() async {
        var started = run
        started.step = .making
        started.startedAt = now()
        started.isHidden = false
        started.concepts.removeAll { $0.isMadeByClaudeDesign }
        started.pickedID = nil
        started.revisingID = nil
        started.revisionRequest = nil
        started.expectedCount = 3
        started.claudeRunID = nil
        // The sheet closes at once: the concepts fill in on the event.
        started.isHidden = studio.watchedKey != key
        studio.begin(started)
        studio.presentedKey = nil
        isChanging = false
        await startClaude(EventArtworkPrompt.text(
            app: app.name, appID: app.id, event: event.referenceName, eventID: event.id, count: 3, makesMotion: started.makesMotion
        ))
    }

    /// Make Them Move: Claude animates the concepts already drawn,
    /// keeping them as they are; the person chooses among the moving ones.
    func addMotion() async {
        let concepts = run.stillConcepts
        guard run.canAddMotion, !concepts.isEmpty else { return }
        studio.update(key) { run in
            run.makesMotion = true
            run.animatingIDs = concepts.map(\.id)
            run.step = .making
            run.startedAt = now()
            run.claudeRunID = nil
        }
        await startClaude(EventArtworkPrompt.motion(
            app: app.name, appID: app.id, event: event.referenceName, eventID: event.id, concepts: concepts.map(\.name)
        ))
    }

    private func startClaude(_ prompt: String) async {
        if let id = await launch(EventArtworkPrompt.purpose(eventID: event.id), prompt) {
            studio.update(key) { $0.claudeRunID = id }
            copiedPrompt = nil
        } else {
            copy(prompt)
            copiedPrompt = prompt
        }
    }

    // MARK: - Making

    var readyCount: Int { run.designedCount }

    var minutesLeft: Int {
        guard run.revisingID == nil else { return 3 }
        if run.isAnimating { return EventArtworkBrief.motionMinutes(concepts: run.animating.count) }
        return EventArtworkBrief.minutesLeft(style: run.style, wordsInArt: run.wordsInArt, makesMotion: run.makesMotion, ready: readyCount)
    }

    /// 0–1 for the bar.
    var progress: Double {
        if run.revisingID != nil { return 0.5 }
        if run.isAnimating {
            let total = max(1, run.stillConcepts.count + run.concepts.count { !$0.videos.isEmpty && $0.isMadeByClaudeDesign })
            let done = total - run.animating.count
            return min(1, (Double(done) + 0.35) / Double(total))
        }
        return min(1, (Double(readyCount) + 0.35) / Double(max(1, run.expectedCount)))
    }

    var progressText: String {
        if let revising = run.revising {
            return String(localized: "Changing “\(revising.name)” · about \(minutesLeft) min left")
        }
        if run.isAnimating {
            let left = run.animating.count
            let lead = left == 1 ? String(localized: "Adding motion to 1 concept") : String(localized: "Adding motion to \(left) concepts")
            return String(localized: "\(lead) · about \(minutesLeft) min left")
        }
        return EventArtworkBrief.progress(ready: readyCount, of: run.expectedCount, minutesLeft: minutesLeft)
    }

    /// Stop: Claude Code ends and nothing is added. A change being drawn
    /// goes back to Check with the concept as it was.
    func stop() {
        if let id = run.claudeRunID { stopClaude(id) }
        if run.revisingID != nil {
            studio.update(key) { run in
                run.revisingID = nil
                run.revisionRequest = nil
                run.claudeRunID = nil
                run.step = .check
            }
            return
        }
        if run.isAnimating {
            studio.update(key) { run in
                run.animatingIDs = nil
                run.claudeRunID = nil
                run.step = .choose
            }
            return
        }
        studio.remove(key)
        onToast(ToastMessage(text: String(localized: "Stopped. Nothing was added to the event.")), nil)
    }

    /// Cancel on the Brief: a run that never started is gone.
    func close() {
        if isStarted, step == .brief, run.usedConceptID == nil, run.concepts.isEmpty { studio.remove(key) }
        studio.presentedKey = nil
    }

    // MARK: - The concepts on the event

    /// The concept the event's preview shows: the one clicked, unless
    /// another is used and the person isn't changing it; else the used
    /// one; else Claude's pick, or the first that's ready.
    var previewConcept: EventArtworkConcept? {
        let run = run
        if let id = run.pickedID, let concept = run.concepts.first(where: { $0.id == id }),
           run.usedConceptID == nil || isChanging || id == run.usedConceptID || run.used == nil
        {
            return concept
        }
        if let used = run.used { return used }
        return run.concepts.first { $0.isPick } ?? run.concepts.first
    }

    /// A click on a concept's row: the preview shows it. Nothing is chosen.
    func preview(_ id: EventArtworkConcept.ID) {
        studio.update(key) { $0.pickedID = id }
    }

    /// Change…: the concepts come back, the used one in the preview.
    func change() {
        isChanging = true
        studio.update(key) { run in run.pickedID = run.usedConceptID ?? run.pickedID }
    }

    /// Keep Current: back to the used concept.
    func keepCurrent() {
        isChanging = false
        studio.update(key) { run in run.pickedID = run.usedConceptID ?? run.pickedID }
    }

    // MARK: - Ask for Changes

    /// The languages worth a look: the primary one, the longest name, a
    /// CJK one and a right-to-left one, as the event has them.
    var checkLocales: [String] {
        let locales = run.locales
        var picked = [run.primaryLocale]
        let name = { (code: String) in self.event.localization(code)?.name.count ?? 0 }
        if let longest = locales.max(by: { name($0) < name($1) }) { picked.append(longest) }
        if let cjk = locales.first(where: { ["ja", "zh", "ko"].contains(String($0.prefix(2))) }) { picked.append(cjk) }
        if let rtl = locales.first(where: { StoreLocaleCatalog.locale(code: $0)?.isRTL == true }) { picked.append(rtl) }
        var seen = Set<String>()
        return picked.filter { seen.insert($0).inserted }
    }

    static let changeChips = [String(localized: "Warmer"), String(localized: "More snow"), String(localized: "Show the app")]

    /// Send to Claude: only that concept's pair is redrawn, in
    /// place; the concept stays where it is while it's drawn.
    func sendChanges(_ request: String, to id: EventArtworkConcept.ID) async {
        let text = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let concept = run.concepts.first(where: { $0.id == id }), !text.isEmpty, concept.isMadeByClaudeDesign,
              run.revisingID == nil, run.step != .making else { return }
        studio.update(key) { run in
            run.revisingID = concept.id
            run.revisionRequest = text
            run.step = .making
            run.startedAt = now()
        }
        await startClaude(EventArtworkPrompt.revision(
            app: app.name, appID: app.id, event: event.referenceName, eventID: event.id, concept: concept.name
        ))
    }
}

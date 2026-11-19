//
//  EventArtworkStudio.swift
//  Atlas
//

import Foundation
import Observation

/// Every event's artwork run (board 47): what the person asked for, the
/// concepts Claude sent, the one picked and the one used. It
/// outlives the sheet, so a hidden run keeps going: the event's media
/// strip and the menu bar show it. JSON in Application Support when given
/// a directory; in memory otherwise (tests, DEBUG scenes).
@MainActor
@Observable
final class EventArtworkStudio {
    static let shared = EventArtworkStudio(directory: sharedDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/EventArtworkRuns")
    }

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return defaultDirectory
    }

    private(set) var runs: [EventArtworkRun.Key: EventArtworkRun] = [:]
    /// The run whose Brief is open in the sheet.
    var presentedKey: EventArtworkRun.Key?
    /// The event whose page is on screen: its run needs no dot or
    /// notification, the person sees it.
    var watchedKey: EventArtworkRun.Key?
    /// A concept arrived or the run ended: the sheet's live lines read it.
    @ObservationIgnored var onConceptArrived: (@MainActor (EventArtworkRun) -> Void)?
    @ObservationIgnored private let directory: URL?

    init(directory: URL? = nil, runs: [EventArtworkRun] = []) {
        self.directory = directory
        let saved = directory.flatMap { Self.read(at: Self.file(in: $0)) } ?? []
        for run in saved + runs { self.runs[run.key] = run }
        // The Claude Code Atlas started ended with the last launch: what it
        // sent goes on to Choose. A prompt pasted elsewhere keeps going.
        for run in saved where run.step == .making && run.claudeRunID != nil {
            runEnded(run.key)
        }
    }

    // MARK: - Reading

    func run(appID: StoreApp.ID, eventID: InAppEvent.ID) -> EventArtworkRun? {
        runs[EventArtworkRun.Key(appID: appID, eventID: eventID)]
    }

    func runs(for appID: StoreApp.ID) -> [EventArtworkRun] {
        runs.values.filter { $0.appID == appID }.sorted { $0.eventName < $1.eventName }
    }

    /// Runs Claude is drawing: the menu bar's working icon.
    var makingRuns: [EventArtworkRun] {
        runs.values.filter { $0.step == .making }.sorted { $0.eventName < $1.eventName }
    }

    /// Runs whose concepts are all in, not seen yet: the dot on the menu
    /// bar icon.
    var readyRuns: [EventArtworkRun] {
        runs.values.filter { $0.isHidden && $0.step == .choose && !$0.concepts.isEmpty && $0.key != watchedKey }
            .sorted { $0.eventName < $1.eventName }
    }

    /// The event's page shows the run: what's in is seen.
    func watch(_ key: EventArtworkRun.Key?) {
        watchedKey = key
        guard let key, let run = runs[key], run.isHidden, run.step != .making else { return }
        update(key) { $0.isHidden = false }
    }

    // MARK: - Changing

    /// A new run, or the one there replaced (a new brief).
    func begin(_ run: EventArtworkRun) {
        runs[run.key] = run
        save()
    }

    /// Changes one run; nothing when there's none.
    func update(_ key: EventArtworkRun.Key, _ change: (inout EventArtworkRun) -> Void) {
        guard var run = runs[key] else { return }
        change(&run)
        guard run != runs[key] else { return }
        runs[key] = run
        save()
    }

    /// A concept from Claude: a new one, or the revision of the one
    /// being changed, which takes its place and keeps its id. When the last
    /// one arrives the run moves on to Choose (Check after a revision).
    @discardableResult
    func add(_ concept: EventArtworkConcept, to key: EventArtworkRun.Key, replacing replaced: EventArtworkConcept.ID? = nil) -> EventArtworkRun? {
        guard runs[key] != nil else { return nil }
        update(key) { run in
            if let replaced, let index = run.concepts.firstIndex(where: { $0.id == replaced }) {
                var revised = concept
                revised.id = replaced
                revised.isPick = run.concepts[index].isPick
                revised.revisedAt = run.revisingID == replaced ? concept.arrivedAt : run.concepts[index].revisedAt
                run.concepts[index] = revised
                if run.revisingID == replaced {
                    run.revisingID = nil
                    run.revisionRequest = nil
                    run.pickedID = replaced
                    if run.step == .making { run.step = .check }
                }
                if var ids = run.animatingIDs, let at = ids.firstIndex(of: replaced) {
                    ids.remove(at: at)
                    run.animatingIDs = ids.isEmpty ? nil : ids
                    if ids.isEmpty, run.step == .making { run.step = .choose }
                }
            } else {
                var added = concept
                if run.concepts.contains(where: { $0.id == added.id }) { added.id = run.nextConceptID }
                if added.isPick { run.concepts.indices.forEach { run.concepts[$0].isPick = false } }
                run.concepts.append(added)
                if run.step == .making, run.revisingID == nil, run.isComplete { run.step = .choose }
            }
        }
        if key == watchedKey, runs[key]?.isHidden == true, runs[key]?.step != .making { update(key) { $0.isHidden = false } }
        let run = runs[key]
        if let run { onConceptArrived?(run) }
        return run
    }

    /// Claude Code ended (finished, stopped or failed) while drawing: what
    /// arrived goes on to Choose, as if all had; nothing back to the Brief,
    /// with the person's words kept. A revision that didn't arrive goes
    /// back to Check with the concept as it was; motion that didn't arrive
    /// leaves those concepts still, at Choose.
    func runEnded(_ key: EventArtworkRun.Key) {
        update(key) { run in
            guard run.step == .making else { return }
            run.claudeRunID = nil
            if run.revisingID != nil {
                run.revisingID = nil
                run.step = .check
            } else if run.isAnimating {
                // What got its motion keeps it; the rest stay still.
                run.animatingIDs = nil
                run.step = .choose
            } else if run.designedCount > 0 {
                run.expectedCount = run.designedCount
                run.step = .choose
            } else {
                run.step = .brief
                run.isHidden = false
            }
        }
    }

    /// The launcher's word that a Claude Code session ended: the run it
    /// was drawing for moves on (`runEnded`).
    func claudeRunEnded(_ session: ClaudeCodeRun) {
        guard case let .eventArtworkConcepts(eventID) = session.purpose else { return }
        let key = EventArtworkRun.Key(appID: session.appID, eventID: eventID)
        guard runs[key]?.claudeRunID == session.id else { return }
        runEnded(key)
    }

    /// Stop, or Cancel at the Brief: the run is gone and nothing was added.
    func remove(_ key: EventArtworkRun.Key) {
        runs[key] = nil
        if presentedKey == key { presentedKey = nil }
        save()
    }

    #if DEBUG
    /// DEBUG scenes: every run at once, and the one whose sheet is open.
    func load(_ runs: [EventArtworkRun], presenting key: EventArtworkRun.Key? = nil) {
        self.runs = Dictionary(runs.map { ($0.key, $0) }) { $1 }
        presentedKey = key
    }
    #endif

    // MARK: - Files

    private func save() {
        guard let directory else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let saved = runs.values.sorted { ($0.appID, $0.eventID) < ($1.appID, $1.eventID) }
        try? encoder.encode(saved).write(to: Self.file(in: directory), options: .atomic)
    }

    private static func file(in directory: URL) -> URL {
        directory.appending(path: "runs.json")
    }

    private static func read(at url: URL) -> [EventArtworkRun]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([EventArtworkRun].self, from: data)
    }
}

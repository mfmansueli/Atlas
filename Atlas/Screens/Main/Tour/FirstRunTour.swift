//
//  FirstRunTour.swift
//  Atlas
//

import Foundation
import Observation

/// The first-run tour (board 63): which tip shows, if any. TipKit draws
/// the tips (`TourTip`, `TourTipModifier`); this keeps their order. It starts by
/// itself once per Mac, the first time the main window shows an app after
/// connecting, and the sidebar's Show the Tour starts it again. Next moves
/// to the following tip and Done ends it; Skip the Tour and the close
/// button end it on any tip; the last tip's Connect an Assistant… ends it
/// on Settings → AI Assistants.
@MainActor
@Observable
final class FirstRunTour {
    /// What a tip's second button leads to.
    enum Outcome: Equatable {
        /// The tour ended.
        case ended
        /// The tour ended; Settings opens on AI Assistants.
        case connectsAssistant
    }

    /// `UserDefaults` key: the tour has started once on this Mac.
    static let shownKey = "firstRunTourShown"

    /// The tip showing; nil while the tour isn't.
    private(set) var step: TourStep?

    /// This start of the tour: its TipKit tips are new each time it starts
    /// (see `TourTip`).
    private(set) var run = UUID().uuidString

    /// Nil keeps whether it was shown in memory only (DEBUG scenes, tests).
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private var shownInMemory = false

    /// Where the live window's tour remembers it was shown: this Mac's
    /// defaults, but never the person's in the unit tests' host.
    static var liveDefaults: UserDefaults? {
        #if DEBUG
        if UnitTestHost.isRunning { return nil }
        #endif
        return .standard
    }

    init(defaults: UserDefaults? = nil, step: TourStep? = nil) {
        self.defaults = defaults
        self.step = step
    }

    var isShowing: Bool { step != nil }

    /// Whether the tour has started on this Mac before.
    var hasBeenShown: Bool {
        defaults?.bool(forKey: Self.shownKey) ?? shownInMemory
    }

    /// Shows the first tip (or `step`), from Show the Tour or the first run.
    func start(at step: TourStep = .apps) {
        run = UUID().uuidString
        self.step = step
        markShown()
    }

    /// The tip to start on once the window shows an app: `opening` (a
    /// DEBUG scene's), else the first when the tour starts by itself and
    /// never started on this Mac. Nil while a tip shows.
    func dueStep(opening: TourStep? = nil, startsOnFirstRun: Bool) -> TourStep? {
        guard !isShowing else { return nil }
        if let opening { return opening }
        return startsOnFirstRun && !hasBeenShown ? .apps : nil
    }

    /// Next, or Done on the last tip.
    func next() {
        step = step?.next
    }

    /// The tip's second button: Skip the Tour, or the last tip's Connect an
    /// Assistant….
    func alternative() -> Outcome {
        let wasLast = step?.isLast == true
        step = nil
        return wasLast ? .connectsAssistant : .ended
    }

    /// The tip's close button.
    func close() {
        step = nil
    }

    /// A tip's popover closed by itself (a click elsewhere, Escape): the
    /// tour ends, unless another tip already took its place.
    func tipClosed(_ closed: TourStep) {
        if step == closed { step = nil }
    }

    private func markShown() {
        shownInMemory = true
        defaults?.set(true, forKey: Self.shownKey)
    }
}

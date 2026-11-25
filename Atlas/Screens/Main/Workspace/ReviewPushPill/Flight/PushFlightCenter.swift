//
//  PushFlightCenter.swift
//  Atlas
//

import AppKit
import Observation

/// “Sent to Review & Push” (board 80): when the person clicks something
/// that sends a change to Review & Push (Accept on a field, a caption, a
/// price, a header, a chat's suggestion card, Accept All…), a blue chip
/// naming it flies from the click to Review & Push at the bottom, which
/// pulses as it lands and its count goes up then. The toast with Undo
/// stays. With Reduce Motion nothing flies; the count just changes.
///
/// It needs nothing from the Accept buttons: it watches the app's clicks
/// (`PushFlightEventMonitor`) and Review & Push's pill tells it what
/// joined (`queueChanged`). A change that joins within a second of a
/// click, with no typing since, came from that click; typing, the
/// assistant's own proposals and Undo fly nothing. A button can name its
/// chip itself first with `nameNextFlight`. Several accepts in a row fly
/// together, at most three in the air.
@MainActor
@Observable
final class PushFlightCenter {
    static let shared = PushFlightCenter(presenter: PushFlightPanel(), landsByItself: true)

    /// A change joining later than this after the click didn't come from it.
    static let clickWindow: TimeInterval = 1
    /// More in the air at once lands the oldest straight away.
    static let maxInAir = 3

    /// The chips in the air, oldest first.
    private(set) var flights: [PushFlight] = []
    /// Goes up as each chip lands: Review & Push pulses.
    private(set) var landings = 0

    /// Review & Push's pill, which the chips land on.
    @ObservationIgnored let anchor = AskAnchor()
    /// Its frame on screen while it shows; tests set their own.
    @ObservationIgnored var targetFrame: @MainActor () -> CGRect?
    /// The person's last click on screen, and when.
    @ObservationIgnored private(set) var lastClick: (point: CGPoint, at: Date)?
    @ObservationIgnored private var hint: (label: String, at: Date)?
    @ObservationIgnored private let presenter: (any PushFlightPresenting)?
    @ObservationIgnored private let landsByItself: Bool
    @ObservationIgnored private var monitor: PushFlightEventMonitor?

    /// `landsByItself`: each chip lands when its flight ends; tests land
    /// them with `land(_:)`.
    init(presenter: (any PushFlightPresenting)? = nil, landsByItself: Bool = false) {
        self.presenter = presenter
        self.landsByItself = landsByItself
        targetFrame = { nil }
        targetFrame = { [anchor] in anchor.screenFrame }
    }

    /// What the chips in the air will add to the count when they land.
    var unitsInAir: Int { flights.reduce(0) { $0 + $1.units } }

    /// The window Review & Push is in, which the chips fly over.
    var targetWindow: NSWindow? { anchor.view?.window }

    // MARK: - What the person does

    /// Starts watching the app's clicks and typing, once.
    func startWatchingClicks() {
        guard monitor == nil else { return }
        monitor = PushFlightEventMonitor(center: self)
    }

    /// A click, on screen.
    func noteClick(at point: CGPoint, now: Date = .now) {
        lastClick = (point, now)
    }

    /// The person types: what joins now is what they typed, not a click's.
    func noteTyping() {
        lastClick = nil
    }

    /// The next chip says `label` instead of the name of what joined.
    func nameNextFlight(_ label: String, now: Date = .now) {
        hint = (label, now)
    }

    // MARK: - Flights

    /// Review & Push's contents went from `old` to `new`: when something
    /// joined right after a click, it flies from there. Returns the flight.
    @discardableResult
    func queueChanged(from old: PushQueueSnapshot, to new: PushQueueSnapshot, reduceMotion: Bool, now: Date = .now) -> PushFlight? {
        guard var label = PushFlightLabel.make(labels: new.joinedLabels(since: old), images: new.joinedImages(since: old)),
              let click = lastClick, now.timeIntervalSince(click.at) <= Self.clickWindow else { return nil }
        // One click, one chip.
        lastClick = nil
        if let hint, now.timeIntervalSince(hint.at) <= Self.clickWindow { label = hint.label }
        hint = nil
        return launch(label: label, from: click.point, units: max(0, new.count - old.count), reduceMotion: reduceMotion, now: now)
    }

    /// Flies a chip from `start` to Review & Push. Nil with Reduce Motion
    /// or while Review & Push doesn't show: the count just changes.
    @discardableResult
    func launch(label: String, from start: CGPoint, units: Int = 1, reduceMotion: Bool, now: Date = .now) -> PushFlight? {
        guard !reduceMotion, let target = targetFrame() else { return nil }
        while flights.count >= Self.maxInAir, let oldest = flights.first {
            land(oldest.id)
        }
        let flight = PushFlight(label: label, start: start, target: CGPoint(x: target.midX, y: target.midY), units: units, launchedAt: now)
        flights.append(flight)
        if flights.count == 1 { presenter?.present(self) }
        if landsByItself {
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(PushFlightPath.duration))
                self?.land(flight.id)
            }
        }
        return flight
    }

    #if DEBUG
    /// DEBUG: one chip held still `elapsed` into its flight from `start`
    /// (on screen), as the design's board draws it mid-air; it never lands.
    func showFrozen(label: String, from start: CGPoint, units: Int = 1, at elapsed: TimeInterval) {
        guard let target = targetFrame() else { return }
        flights = [PushFlight(label: label, start: start, target: CGPoint(x: target.midX, y: target.midY), units: units, frozenAt: elapsed)]
        presenter?.present(self)
    }
    #endif

    /// The chip reached Review & Push: it pulses, and its count takes
    /// what the chip carried.
    func land(_ id: PushFlight.ID) {
        guard let index = flights.firstIndex(where: { $0.id == id }) else { return }
        flights.remove(at: index)
        landings += 1
        if flights.isEmpty { presenter?.dismiss() }
    }
}

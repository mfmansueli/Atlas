//
//  PushFlight.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// One accepted change on its way to Review & Push (board 80): the chip's
/// words, where it starts and lands, and how much it adds to the count
/// when it lands. Points are in the space of what draws it: on screen for
/// the window's overlay (`PushFlightPanel`), the view's own in a DEBUG
/// scene.
struct PushFlight: Identifiable, Equatable, Sendable {
    let id: UUID
    /// “What's New · German”, “Brazil · R$ 9,90”, “3 changes”.
    let label: String
    let start: CGPoint
    let target: CGPoint
    /// What it adds to the count; 0 for a proposal that was already
    /// counted and is accepted now.
    let units: Int
    let launchedAt: Date
    /// DEBUG: drawn still, this far into the flight.
    var frozenAt: TimeInterval?

    init(
        id: UUID = UUID(),
        label: String,
        start: CGPoint,
        target: CGPoint,
        units: Int = 1,
        launchedAt: Date = .now,
        frozenAt: TimeInterval? = nil
    ) {
        self.id = id
        self.label = label
        self.start = start
        self.target = target
        self.units = units
        self.launchedAt = launchedAt
        self.frozenAt = frozenAt
    }
}

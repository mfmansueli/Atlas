//
//  PushFlightPresenting.swift
//  Atlas
//

import Foundation

/// What draws the flights of a `PushFlightCenter` over the window: the
/// app's clear panel (`PushFlightPanel`); tests have none.
@MainActor
protocol PushFlightPresenting: AnyObject {
    /// The first flight took off: start drawing them.
    func present(_ center: PushFlightCenter)
    /// The last one landed.
    func dismiss()
}

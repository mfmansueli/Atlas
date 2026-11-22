//
//  AppAvailabilityState.swift
//  Atlas
//

import Foundation

/// Whether the app has an availability yet. A new app has none (App Store
/// Connect's "Determine where your app will be available… Set Up
/// Availability"), so it isn't sold anywhere.
enum AppAvailabilityState: Hashable, Sendable {
    case notSet
    case set(AppAvailability)

    var availability: AppAvailability? {
        if case let .set(availability) = self { return availability }
        return nil
    }
}

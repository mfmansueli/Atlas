//
//  InAppEventsServices.swift
//  Atlas
//

import Foundation

/// What In-App Events needs from App Store Connect. `LiveInAppEventsServices`
/// reads it; tests and DEBUG scenes use canned events. Changes go through
/// Review & Push like every other edit.
@MainActor
protocol InAppEventsServices {
    /// The app's events with their texts and media in every language,
    /// newest first.
    func events(for app: StoreApp) async throws -> [InAppEvent]
    /// How an ended event did, from Apple's numbers; nil when Atlas
    /// doesn't have them.
    func results(for event: InAppEvent, of app: StoreApp) async -> InAppEventResults?
}

extension InAppEventsServices {
    func results(for _: InAppEvent, of _: StoreApp) async -> InAppEventResults? { nil }
}

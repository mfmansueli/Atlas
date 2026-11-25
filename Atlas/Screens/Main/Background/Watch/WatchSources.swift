//
//  WatchSources.swift
//  Atlas
//

import Foundation

/// What Look for Improvements reads from the main window beyond the stores
/// `MainWindowBackground` has: the switch, Pro, the sections' kept models
/// (What's New, the version's answers), the suggestions and the key's
/// quota. Off and empty until the window sets it.
@MainActor
struct WatchSources {
    /// Settings → Suggestions → "Look for Improvements".
    var isOn: @MainActor () -> Bool = { false }
    var isPro: @MainActor () -> Bool = { false }
    /// An app's section models when the window keeps them, without counting
    /// as opening the app.
    var keptModels: @MainActor (StoreApp.ID) -> AppSectionModels? = { _ in nil }
    var suggestions: FieldSuggestionStore?
    /// App Store Connect's hourly quota for the key, as last read.
    var quota: @MainActor () -> AppStoreConnectRateLimit? = { nil }
}

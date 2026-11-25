//
//  WatchContext.swift
//  Atlas
//

import Foundation

/// What a check knows about the person's setup when it decides whether a
/// Look for Improvements run may start.
struct WatchContext: Hashable, Sendable {
    /// Settings → "Look for Improvements" (off until the person turns it on).
    var isOn = false
    var isPro = false
    /// The Claude Code helper is ready.
    var canStartClaudeCode = false
    /// The apps whose project folder Atlas knows: runs never ask for one.
    var appsWithProjectFolder: Set<StoreApp.ID> = []
    /// Claude Code runs going now, of any kind.
    var activeRunCount = 0
    /// When Claude Code last stopped on the person's usage limit.
    var usageLimitHitAt: Date?
    /// App Store Connect's hourly quota as last read; nil when unknown.
    var quota: AppStoreConnectRateLimit?
}

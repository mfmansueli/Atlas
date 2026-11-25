//
//  WatchBudgetRefusal.swift
//  Atlas
//

import Foundation

/// Why no Look for Improvements run starts for an app now.
enum WatchBudgetRefusal: Hashable, Sendable {
    /// "Look for Improvements" is off.
    case turnedOff
    /// Runs are Pro; the checks themselves aren't.
    case notPro
    /// The Claude Code helper isn't ready.
    case noClaudeCode
    /// Atlas doesn't know the app's project folder, and never asks for one
    /// with nobody looking.
    case noProjectFolder
    /// Between 22:00 and 08:00, until then.
    case quietHours(until: Date)
    /// Another Claude Code run is going.
    case anotherRunActive
    /// Claude Code hit the usage limit lately, until then.
    case usageLimit(until: Date)
    /// App Store Connect's hourly quota is down to its last quarter.
    case quotaLow
    /// This app had its run today.
    case appDailyCap
    /// Three runs today already.
    case dailyCap

    /// "turnedOff", "quietHours"…, for the debug scene.
    var key: String {
        switch self {
        case .turnedOff: "turnedOff"
        case .notPro: "notPro"
        case .noClaudeCode: "noClaudeCode"
        case .noProjectFolder: "noProjectFolder"
        case .quietHours: "quietHours"
        case .anotherRunActive: "anotherRunActive"
        case .usageLimit: "usageLimit"
        case .quotaLow: "quotaLow"
        case .appDailyCap: "appDailyCap"
        case .dailyCap: "dailyCap"
        }
    }
}

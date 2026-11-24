//
//  AppPreferences.swift
//  Atlas
//

import Foundation
import Observation

/// Settings that apply to every app, kept in `UserDefaults`: Settings →
/// Pricing and General. Per-app choices (the pricing mode) live in
/// `PricingModeStore`, translation settings in `TranslationPreferences`.
@MainActor
@Observable
final class AppPreferences {
    /// The pricing mode an app gets when Pricing first opens for it.
    var defaultPricingMode: PricingMode {
        didSet { defaults?.set(defaultPricingMode.rawValue, forKey: Key.defaultPricingMode) }
    }

    /// Pricing → "Use sales data for suggestions", when the key's role can
    /// read Sales and Trends.
    var usesSalesData: Bool {
        didSet { defaults?.set(usesSalesData, forKey: Key.usesSalesData) }
    }

    /// Pricing → the strategy a subscription starts from: base territory,
    /// rounding, index, fallback chain, intensity, limits.
    var pricingDefaults: PricingStrategy {
        didSet { defaults?.set(try? JSONEncoder().encode(pricingDefaults), forKey: Key.pricingDefaults) }
    }

    /// Apple's commission used for proceeds: 15% (Small Business Program) or 30%.
    var commissionRate: Double {
        didSet { defaults?.set(commissionRate, forKey: Key.commissionRate) }
    }

    /// General → "Confirm before pushing".
    var pushConfirmation: PushConfirmation {
        didSet { defaults?.set(pushConfirmation.rawValue, forKey: Key.pushConfirmation) }
    }

    /// General → "Ask before pushing price increases".
    var confirmsPriceIncreases: Bool {
        didSet { defaults?.set(confirmsPriceIncreases, forKey: Key.confirmsPriceIncreases) }
    }

    /// General → "Confirm before discarding".
    var confirmsDiscarding: Bool {
        didSet { defaults?.set(confirmsDiscarding, forKey: Key.confirmsDiscarding) }
    }

    /// Overview → the card introducing your own AI assistant, until its
    /// close button hides it.
    var showsAssistantIntro: Bool {
        didSet { defaults?.set(showsAssistantIntro, forKey: Key.showsAssistantIntro) }
    }

    /// General → Suggestions: Accept All Languages and Accept All Pages
    /// accept at once instead of showing the suggestions first. One setting
    /// for Store Page, Screenshots and App Information.
    var acceptsAllWithoutAsking: Bool {
        didSet { defaults?.set(acceptsAllWithoutAsking, forKey: Key.acceptsAllWithoutAsking) }
    }

    /// General → "Show Atlas in the menu bar". Off also turns off "Keep
    /// running when the window is closed": there would be no way back in.
    var showsMenuBarIcon: Bool {
        didSet {
            defaults?.set(showsMenuBarIcon, forKey: Key.showsMenuBarIcon)
            if !showsMenuBarIcon { keepsRunning = false }
        }
    }

    /// General → "Keep running when the window is closed". Off: closing
    /// the window quits Atlas once nothing is running.
    var keepsRunning: Bool {
        didSet { defaults?.set(keepsRunning, forKey: Key.keepsRunning) }
    }

    /// General → "Show in the Dock".
    var dockVisibility: DockVisibility {
        didSet { defaults?.set(dockVisibility.rawValue, forKey: Key.dockVisibility) }
    }

    /// General → "Animate the menu bar icon while working". Reduce Motion
    /// keeps it still either way.
    var animatesMenuBarIcon: Bool {
        didSet { defaults?.set(animatesMenuBarIcon, forKey: Key.animatesMenuBarIcon) }
    }

    /// General → "Play moving artwork": event and header loops play muted
    /// on repeat where they show, as on the App Store. Off, or with Reduce
    /// Motion, they show a still until Play in the viewer.
    var autoplaysMotion: Bool {
        didSet { defaults?.set(autoplaysMotion, forKey: Key.autoplaysMotion) }
    }

    /// General → "Check App Store Connect".
    var checkInterval: CheckInterval {
        didSet { defaults?.set(checkInterval.rawValue, forKey: Key.checkInterval) }
    }

    /// General → Appearance.
    var appearance: AppAppearance {
        didSet {
            defaults?.set(appearance.rawValue, forKey: Key.appearance)
            appearance.apply()
        }
    }

    /// Settings → Screenshots → "Words in event artwork": the Brief's
    /// default for an event's artwork from Claude.
    var eventArtworkHasWords: Bool {
        didSet { defaults?.set(eventArtworkHasWords, forKey: Key.eventArtworkHasWords) }
    }

    /// Settings → Screenshots → "Also make moving versions": the Brief's
    /// default.
    var eventArtworkMakesMotion: Bool {
        didSet { defaults?.set(eventArtworkMakesMotion, forKey: Key.eventArtworkMakesMotion) }
    }

    /// Settings → Screenshots → "Let Claude Code open capture-only runs":
    /// a `request_recapture` opens the run at once instead of waiting in
    /// Screenshots for Accept. Off by default; nothing reaches App Store
    /// Connect until the person pushes either way.
    var opensCaptureRuns: Bool {
        didSet { defaults?.set(opensCaptureRuns, forKey: Self.opensCaptureRunsKey) }
    }

    /// Where `opensCaptureRuns` is kept: Autopilot reads it when a request
    /// arrives.
    nonisolated static let opensCaptureRunsKey = "opensCaptureRuns"

    /// Settings → Suggestions → "Words repeated between name, subtitle and
    /// keywords": the Store Page's built-in keywords check.
    var checksRepeatedWords: Bool {
        didSet { defaults?.set(checksRepeatedWords, forKey: Key.checksRepeatedWords) }
    }

    /// The confirmations turned off with "Don't ask again" or in Settings:
    /// Accept All without asking, discarding and price increases without
    /// asking, pushing without the last alert.
    var turnedOffConfirmations: Int {
        [acceptsAllWithoutAsking, !confirmsDiscarding, !confirmsPriceIncreases, pushConfirmation == .never].filter(\.self).count
    }

    /// Privacy & Data → Reset: every confirmation asks again.
    func resetConfirmations() {
        acceptsAllWithoutAsking = false
        confirmsDiscarding = true
        confirmsPriceIncreases = true
        if pushConfirmation == .never { pushConfirmation = .overFifty }
    }

    /// Whether the note under the menu bar icon ("Atlas is still running")
    /// was shown, the first time the window closed.
    var hasSeenStillRunningNote: Bool {
        didSet { defaults?.set(hasSeenStillRunningNote, forKey: Key.hasSeenStillRunningNote) }
    }

    /// Whether closing the window leaves Atlas running: only with the menu
    /// bar icon to come back by.
    var staysOpenWhenClosed: Bool { showsMenuBarIcon && keepsRunning }

    private let defaults: UserDefaults?

    /// nil keeps everything in memory (DEBUG scenes, tests).
    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        defaultPricingMode = defaults?.string(forKey: Key.defaultPricingMode).flatMap(PricingMode.init(rawValue:)) ?? .showSuggestions
        usesSalesData = defaults?.object(forKey: Key.usesSalesData) as? Bool ?? true
        pricingDefaults = defaults?.data(forKey: Key.pricingDefaults)
            .flatMap { try? JSONDecoder().decode(PricingStrategy.self, from: $0) } ?? .recommended
        let commission = defaults?.double(forKey: Key.commissionRate) ?? 0
        commissionRate = commission > 0 ? commission : 0.15
        pushConfirmation = defaults?.string(forKey: Key.pushConfirmation).flatMap(PushConfirmation.init(rawValue:)) ?? .overFifty
        confirmsPriceIncreases = defaults?.object(forKey: Key.confirmsPriceIncreases) as? Bool ?? true
        confirmsDiscarding = defaults?.object(forKey: Key.confirmsDiscarding) as? Bool ?? true
        showsAssistantIntro = defaults?.object(forKey: Key.showsAssistantIntro) as? Bool ?? true
        acceptsAllWithoutAsking = defaults?.object(forKey: Key.acceptsAllWithoutAsking) as? Bool ?? false
        let showsMenuBarIcon = defaults?.object(forKey: Key.showsMenuBarIcon) as? Bool ?? true
        self.showsMenuBarIcon = showsMenuBarIcon
        keepsRunning = showsMenuBarIcon && (defaults?.object(forKey: Key.keepsRunning) as? Bool ?? true)
        dockVisibility = defaults?.string(forKey: Key.dockVisibility).flatMap(DockVisibility.init(rawValue:)) ?? .whileWindowOpen
        animatesMenuBarIcon = defaults?.object(forKey: Key.animatesMenuBarIcon) as? Bool ?? true
        autoplaysMotion = defaults?.object(forKey: Key.autoplaysMotion) as? Bool ?? true
        checkInterval = defaults?.string(forKey: Key.checkInterval).flatMap(CheckInterval.init(rawValue:)) ?? .everyHour
        hasSeenStillRunningNote = defaults?.bool(forKey: Key.hasSeenStillRunningNote) ?? false
        appearance = defaults?.string(forKey: Key.appearance).flatMap(AppAppearance.init(rawValue:)) ?? .system
        eventArtworkHasWords = defaults?.bool(forKey: Key.eventArtworkHasWords) ?? false
        eventArtworkMakesMotion = defaults?.bool(forKey: Key.eventArtworkMakesMotion) ?? false
        checksRepeatedWords = defaults?.object(forKey: Key.checksRepeatedWords) as? Bool ?? true
        opensCaptureRuns = defaults?.bool(forKey: Self.opensCaptureRunsKey) ?? false
        // The Guided/Classic choice is gone: the guided Autopilot is the
        // only one.
        defaults?.removeObject(forKey: Key.retiredAutopilotFront)
    }

    private enum Key {
        static let defaultPricingMode = "defaultPricingMode"
        static let usesSalesData = "usesSalesData"
        static let pricingDefaults = "pricingDefaults"
        static let commissionRate = "commissionRate"
        static let pushConfirmation = "pushConfirmation"
        static let confirmsPriceIncreases = "confirmsPriceIncreases"
        static let confirmsDiscarding = "confirmsDiscarding"
        static let showsAssistantIntro = "showsAssistantIntro"
        static let acceptsAllWithoutAsking = "acceptAllWithoutAsking"
        static let retiredAutopilotFront = "autopilotFront"
        static let showsMenuBarIcon = "showsMenuBarIcon"
        static let keepsRunning = "keepsRunningWhenClosed"
        static let dockVisibility = "dockVisibility"
        static let animatesMenuBarIcon = "animatesMenuBarIcon"
        static let autoplaysMotion = "autoplaysMotion"
        static let checkInterval = "checkInterval"
        static let hasSeenStillRunningNote = "hasSeenStillRunningNote"
        static let appearance = "appearance"
        static let eventArtworkHasWords = "eventArtworkHasWords"
        static let eventArtworkMakesMotion = "eventArtworkMakesMotion"
        static let checksRepeatedWords = "checksRepeatedWords"
    }
}

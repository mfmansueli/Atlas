//
//  ProGate.swift
//  Atlas
//

import Foundation
import Observation

/// What every gated button goes through: with Pro, the action runs; in
/// Free, the paywall opens saying what was blocked, and its continue button
/// runs the action once Pro is bought.
@MainActor
@Observable
final class ProGate {
    let entitlements: Entitlements
    /// The paywall while it's open.
    var paywall: PaywallModel?

    @ObservationIgnored private let defaults: UserDefaults?

    /// Free's one app: the first the person opens. Kept, so it's the same
    /// app at the next launch.
    private(set) var freeAppID: String? {
        didSet { defaults?.set(freeAppID, forKey: Self.freeAppKey) }
    }

    static let freeAppKey = "pro.freeAppID"

    init(entitlements: Entitlements, defaults: UserDefaults? = nil) {
        self.entitlements = entitlements
        self.defaults = defaults
        freeAppID = defaults?.string(forKey: Self.freeAppKey)
    }

    /// Whether `appID` may be opened: any app with Pro; in Free the first
    /// one opened, which becomes the free app.
    func mayOpen(appID: String) -> Bool {
        guard isFree else { return true }
        if freeAppID == nil { freeAppID = appID }
        return freeAppID == appID
    }

    var isFree: Bool { !entitlements.isPro }

    /// Whether `appID` needs Pro: in Free, every app but the free one once
    /// it's chosen. Only asks; `mayOpen` is what picks the free app.
    func isLocked(appID: String) -> Bool {
        guard isFree, let freeAppID else { return false }
        return freeAppID != appID
    }

    func require(_ context: PaywallContext, then action: @escaping () -> Void) {
        if let feature = context.feature, !entitlements.canUse(feature) {
            paywall = PaywallModel(context: context, entitlements: entitlements, onContinue: action)
        } else {
            action()
        }
    }

    /// `require` from the Settings window: its paywall opens there.
    func requireInSettings(_ context: PaywallContext, then action: @escaping () -> Void) {
        if let feature = context.feature, !entitlements.canUse(feature) {
            settingsPaywall = PaywallModel(context: context, entitlements: entitlements, onContinue: action)
        } else {
            action()
        }
    }

    // MARK: - Free's limits

    /// Whether another App Store Connect key may be added: any with Pro;
    /// in Free only while fewer than `Entitlements.freeAppLimit` are saved
    /// (the first key, or one put back after removing the old one).
    func mayAddAccount(accountCount: Int) -> Bool {
        !isFree || accountCount < Entitlements.freeAppLimit
    }

    /// Add Another Key…: the sheet, or in Free with a key saved already the
    /// paywall (on the Settings window `inSettings`), whose continue button
    /// opens the sheet once Pro is bought.
    func requireNewAccount(accountCount: Int, inSettings: Bool = false, then action: @escaping () -> Void) {
        if mayAddAccount(accountCount: accountCount) {
            action()
        } else if inSettings {
            requireInSettings(.secondAccount, then: action)
        } else {
            require(.secondAccount, then: action)
        }
    }

    /// Whether `starter` may be picked: any with Pro; in Free one of
    /// `FreePlanLimits.templates`, or the one already in use.
    func mayUse(_ starter: TemplateStarter, inUse: TemplateStarter? = nil) -> Bool {
        !isFree || FreePlanLimits.includes(starter) || starter == inUse
    }

    /// Whether the template editor may show `display`: any with Pro; in
    /// Free iPhone and iPad (`FreePlanLimits.displays`).
    func mayShow(_ display: ScreenshotDisplayType) -> Bool {
        !isFree || FreePlanLimits.includes(display)
    }

    /// The toolbar's Pro button: the plans, with no card.
    func showPlans() {
        paywall = PaywallModel(context: .menu, entitlements: entitlements)
    }

    /// The paywall Settings shows on its own window (See Atlas Pro… in
    /// Settings → Atlas Pro), so it isn't opened behind it on the main one.
    var settingsPaywall: PaywallModel?

    func showPlansInSettings() {
        settingsPaywall = PaywallModel(context: .menu, entitlements: entitlements)
    }

    /// The paywall's continue button: closes it, then finishes what the
    /// person started.
    func finish(_ model: PaywallModel, continues: Bool) {
        paywall = nil
        settingsPaywall = nil
        if continues, entitlements.isPro { model.onContinue?() }
    }
}

/// A view outside the main window (a preview, a DEBUG scene) has no gate:
/// there everything runs, as with Pro.
@MainActor
extension ProGate? {
    var isFree: Bool { self?.isFree ?? false }

    func require(_ context: PaywallContext, then action: @escaping () -> Void) {
        if let self { self.require(context, then: action) } else { action() }
    }

    func requireInSettings(_ context: PaywallContext, then action: @escaping () -> Void) {
        if let self { self.requireInSettings(context, then: action) } else { action() }
    }

    func mayAddAccount(accountCount: Int) -> Bool {
        self?.mayAddAccount(accountCount: accountCount) ?? true
    }

    func requireNewAccount(accountCount: Int, inSettings: Bool = false, then action: @escaping () -> Void) {
        if let self { self.requireNewAccount(accountCount: accountCount, inSettings: inSettings, then: action) } else { action() }
    }

    func mayUse(_ starter: TemplateStarter, inUse: TemplateStarter? = nil) -> Bool {
        self?.mayUse(starter, inUse: inUse) ?? true
    }

    func mayShow(_ display: ScreenshotDisplayType) -> Bool {
        self?.mayShow(display) ?? true
    }
}

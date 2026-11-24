//
//  ReviewShotsRunCenter.swift
//  Atlas
//

import Foundation
import Observation

/// The Make Review Screenshots… runs, one per app, for Pricing's cards and
/// banners, the toolbar's Autopilot button and the MCP tools that report
/// them. It also keeps where each app's paywall is, as the person said it
/// after a run that couldn't find it, and how many products Pricing last
/// saw missing a review screenshot (the Autopilot menu's “3 missing”).
@MainActor
@Observable
final class ReviewShotsRunCenter {
    static let shared = ReviewShotsRunCenter(defaults: ReviewShotDetailsStore.liveDefaults)

    /// `UserDefaults` key of the routes, by app.
    static let routesKey = "reviewShotsPaywallRoutes"

    private(set) var runs: [StoreApp.ID: ReviewShotsRun] = [:]
    /// “Settings → Lumen Plus”, by app.
    private(set) var routes: [StoreApp.ID: String] = [:]
    /// Products missing a review screenshot, by app, as Pricing last read.
    private(set) var missing: [StoreApp.ID: Int] = [:]
    @ObservationIgnored private let defaults: UserDefaults?

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        routes = defaults?.dictionary(forKey: Self.routesKey) as? [String: String] ?? [:]
    }

    func run(for appID: StoreApp.ID) -> ReviewShotsRun? {
        runs[appID]
    }

    /// The run while it works.
    func workingRun(for appID: StoreApp.ID) -> ReviewShotsRun? {
        runs[appID].flatMap { $0.isWorking ? $0 : nil }
    }

    // MARK: - The run

    /// A new run for `products`, in place of any other.
    @discardableResult
    func start(appID: StoreApp.ID, client: String, products: [ReviewShotsRun.Product]) -> ReviewShotsRun {
        let run = ReviewShotsRun(client: client, products: products)
        runs[appID] = run
        return run
    }

    /// A step from the assistant; `productID` is the product it captures now.
    func report(appID: StoreApp.ID, productID: String?, step: String?) {
        guard var run = runs[appID], run.isWorking else { return }
        if let productID, productID != run.current {
            if let current = run.current, current != productID, let step = run.step { run.steps.append(step) }
            run.current = productID
            run.step = nil
        }
        if let step, !step.isEmpty {
            if let previous = run.step, previous != step { run.steps.append(previous) }
            run.step = step
        }
        runs[appID] = run
    }

    /// The image of `productID` arrived as a suggestion.
    func arrived(appID: StoreApp.ID, productID: String) {
        guard var run = runs[appID] else { return }
        run.arrived.insert(productID)
        if run.current == productID {
            run.current = nil
            run.step = nil
        }
        runs[appID] = run
    }

    /// It stopped: the paywall wasn't found, or showed no prices.
    func fail(appID: StoreApp.ID, _ phase: ReviewShotsRun.Phase) {
        guard var run = runs[appID] else { return }
        run.phase = phase
        run.current = nil
        run.step = nil
        runs[appID] = run
    }

    /// The assistant's run ended: a run still working is over, ready
    /// when images arrived (they stay as suggestions); a failure stays
    /// until Not Now or Try Again. Returns the toast's text when “they
    /// wait in Pricing” isn't true: nothing or only some arrived, or it
    /// stopped.
    @discardableResult
    func runEnded(appID: StoreApp.ID) -> String? {
        guard var run = runs[appID] else { return nil }
        switch run.phase {
        case .paywallNotFound, .noPrices:
            return String(localized: "\(run.client) stopped before the review screenshots. Pricing says why.")
        case .ready:
            return nil
        case .working:
            guard !run.arrived.isEmpty else {
                runs[appID] = nil
                guard let step = run.step else { return String(localized: "\(run.client) made no review screenshots.") }
                return String(localized: "\(run.client) made no review screenshots. Its last step: \(step)")
            }
            run.phase = .ready
            run.current = nil
            run.step = nil
            runs[appID] = run
            guard run.arrived.count < run.products.count else { return nil }
            return String(
                localized: "\(run.client) made \(run.arrived.count) of \(run.products.count) review screenshots. What it made waits in Pricing."
            )
        }
    }

    /// Once nothing it made waits for Accept, a ready run is over.
    func settle(appID: StoreApp.ID, suggestionsLeft: Int) {
        guard runs[appID]?.phase == .ready, suggestionsLeft == 0 else { return }
        runs[appID] = nil
    }

    /// Cancel Run… or Not Now.
    func clear(appID: StoreApp.ID) {
        runs[appID] = nil
    }

    // MARK: - What Pricing knows

    func setRoute(_ route: String, for appID: StoreApp.ID) {
        let trimmed = route.trimmingCharacters(in: .whitespacesAndNewlines)
        routes[appID] = trimmed.isEmpty ? nil : trimmed
        defaults?.set(routes, forKey: Self.routesKey)
    }

    /// What the Autopilot menu says beside Make Review Screenshots…: “3
    /// missing”; “Running” or “All set”, and it can't be chosen; nothing
    /// before Pricing has read the products.
    func menuNote(for appID: StoreApp.ID) -> (text: String?, isEnabled: Bool) {
        if workingRun(for: appID) != nil { return (String(localized: "Running"), false) }
        switch missing[appID] {
        case nil: return (nil, true)
        case 0?: return (String(localized: "All set"), false)
        case let count?: return (String(localized: "\(count) missing"), true)
        }
    }

    func setMissing(_ count: Int, for appID: StoreApp.ID) {
        guard missing[appID] != count else { return }
        missing[appID] = count
    }
}

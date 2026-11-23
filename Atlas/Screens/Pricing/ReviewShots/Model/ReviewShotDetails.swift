//
//  ReviewShotDetails.swift
//  Atlas
//

import Foundation

/// What Atlas knows of a review screenshot waiting in Review & Push beyond
/// its file: where it came from, the plan it shows selected and the checks
/// it passed. The cards, the preview and Review & Push say it.
struct ReviewShotDetails: Codable, Hashable, Sendable {
    enum Origin: Codable, Hashable, Sendable {
        /// Captured by an assistant in Simulator.
        case assistant(client: String)
        /// A Screenshots capture, “Capture 14 · Paywall”.
        case capture(title: String)
    }

    var origin: Origin
    /// “Monthly”: the plan selected in it.
    var plan: String?
    /// The product's own plan, when it isn't `plan`: Bruma's paywall
    /// selects Annual and nothing selects Monthly without a tap, so
    /// Monthly's image shows Monthly and its price with Annual selected.
    var expectedPlan: String?
    /// “$4.99”: the price it shows for that plan.
    var price: String?
    /// “iPhone 17 Pro”.
    var device: String?
    /// “English (U.S.)”.
    var language: String?
    /// What was checked before it showed: “Price shows”, “Monthly
    /// selected”, “No test or debug banner”.
    var checks: [String] = []
    var madeAt: Date = .now

    var isFromAssistant: Bool {
        if case .assistant = origin { return true }
        return false
    }

    /// The client's name, for “From Claude Code”.
    var client: String? {
        if case let .assistant(client) = origin { return client }
        return nil
    }

    /// Another plan than the product's is selected in it.
    var showsOtherPlan: Bool {
        guard let plan, let expectedPlan else { return false }
        return plan.localizedCaseInsensitiveCompare(expectedPlan) != .orderedSame
    }

    /// “Monthly selected”, or “Monthly shows, Annual selected”.
    var planText: String? {
        guard let plan else { return nil }
        if showsOtherPlan, let expectedPlan { return String(localized: "\(expectedPlan) shows, \(plan) selected") }
        return String(localized: "\(plan) selected")
    }

    /// “Review screenshot · Monthly selected”.
    var heading: String {
        planText.map { String(localized: "Review screenshot · \($0)") } ?? String(localized: "Review screenshot")
    }

    /// “Captured in Simulator on iPhone 17 Pro, English (U.S.), just now.
    /// Monthly is selected and shows $4.99.”
    func capturedLine(now: Date = .now) -> String {
        let when = now.timeIntervalSince(madeAt) < 60
            ? String(localized: "just now")
            : madeAt.formatted(.relative(presentation: .named, unitsStyle: .wide))
        let place = [device, language].compactMap(\.self).joined(separator: ", ")
        var line = place.isEmpty ? String(localized: "Captured in Simulator \(when).") : String(localized: "Captured in Simulator on \(place), \(when).")
        if showsOtherPlan, let plan, let expectedPlan {
            let shows = price.map { String(localized: "\(expectedPlan) shows \($0)") } ?? String(localized: "\(expectedPlan) shows")
            line += " " + String(localized: "\(shows), with \(plan) selected.")
        } else if let plan, let price {
            line += " " + String(localized: "\(plan) is selected and shows \(price).")
        } else if let plan {
            line += " " + String(localized: "\(plan) is selected.")
        }
        return line
    }

    /// “From Claude Code · Monthly selected · uploads when you push”, or
    /// “Capture 14 · Paywall from Screenshots · uploads when you push”.
    var acceptedLine: String {
        switch origin {
        case let .assistant(client):
            let plan = planText.map { " · " + $0 } ?? ""
            return String(localized: "From \(client)\(plan) · uploads when you push")
        case let .capture(title):
            return String(localized: "\(title) from Screenshots · uploads when you push")
        }
    }

    /// “Review screenshot · Monthly selected · from Claude Code”, for
    /// Review & Push.
    var reviewLine: String {
        switch origin {
        case let .assistant(client):
            let plan = planText.map { " · " + $0 } ?? ""
            return String(localized: "Review screenshot\(plan) · from \(client)")
        case let .capture(title):
            return String(localized: "Review screenshot · \(title) from Screenshots")
        }
    }
}

//
//  AIProgress.swift
//  Atlas
//

import Foundation

/// Effect 2 · Working, counted (README — Design system §7, v2): progress is
/// real units of the plan (captures, screens × languages, fields, products,
/// requests), never time. Up to about 20 units it reads “2 of 3”; above,
/// “38% · 97 of 255”. Time left shows only once a few units are done, from
/// their real average. Work without units has no `AIProgress`: only the
/// step's name (`AIWorkingStep`).
struct AIProgress: Equatable, Sendable {
    let done: Int
    let total: Int

    /// Up to this many units the label counts; above, it adds a percentage.
    static let countLimit = 20
    /// Units done before time left is worth saying.
    static let unitsBeforeTimeLeft = 3

    init(done: Int, total: Int) {
        self.total = max(total, 0)
        self.done = min(max(done, 0), self.total)
    }

    /// 0–1, for the bar.
    var fraction: Double {
        total > 0 ? Double(done) / Double(total) : 0
    }

    /// “2 of 3”, or “38% · 97 of 255” above 20 units.
    var label: String {
        guard total > Self.countLimit else { return String(localized: "\(done) of \(total)", comment: "kind:progress-step") }
        let percent = Int((fraction * 100).rounded(.down))
        return String(localized: "\(percent)% · \(done) of \(total)", comment: "kind:progress-step")
    }

    /// Seconds left from the real average of the units so far, `elapsed`
    /// seconds since the first began; nil until a few are done, and once
    /// all are.
    func secondsLeft(elapsed: TimeInterval) -> TimeInterval? {
        guard done >= Self.unitsBeforeTimeLeft, done < total, elapsed > 0 else { return nil }
        return elapsed / Double(done) * Double(total - done)
    }

    /// “about 6 min left”, or nil while it's too early to say.
    func timeLeft(elapsed: TimeInterval) -> String? {
        guard let seconds = secondsLeft(elapsed: elapsed) else { return nil }
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        guard minutes >= 60 else { return String(localized: "about \(minutes) min left") }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? String(localized: "about \(hours) h left") : String(localized: "about \(hours) h \(rest) min left")
    }

    /// The label with time left when there is one: “97 of 255 · about 6
    /// min left”.
    func line(elapsed: TimeInterval) -> String {
        guard let left = timeLeft(elapsed: elapsed) else { return label }
        return "\(label) · \(left)"
    }
}

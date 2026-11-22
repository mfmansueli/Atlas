//
//  AutopilotProblem+MissingSimulator.swift
//  Atlas
//

import Foundation

/// A device-wide problem that says the device has no simulator: Alba's
/// pr-40a1e4a1, reported as next_step said ("There's no iPhone Duo simulator
/// on this Mac yet"), and Atlas's own "This Mac can't run the … simulator".
/// Once the simulator is there (or Atlas can make it), it's solved without
/// the person.
extension AutopilotProblem {
    /// About the device's simulator not being there, not about one that's
    /// there (closed, stuck, a crash).
    var isAboutMissingSimulator: Bool {
        guard isDeviceWide, changesProject != true, !wasRefused else { return false }
        let text = Self.normalized([what, proposedFix ?? ""].joined(separator: " "))
        return Self.missingPatterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    /// Lowercased, with typographic apostrophes as plain ones.
    private static func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'").replacingOccurrences(of: "\u{2018}", with: "'")
    }

    /// "no iphone duo simulator", "can't run the … simulator", "simulator
    /// isn't installed", "simctl create", "make the … simulator".
    private static let missingPatterns = [
        #"\bno ([\w-]+ ){0,4}simulators?\b"#,
        #"\b(can't|cannot|can not|couldn't) (run|find) (the |an? )?([\w-]+ ){0,4}simulator"#,
        #"\bsimulators?\b.{0,40}\b(isn't|is not|not|wasn't|aren't) (installed|made|created|available|there)\b"#,
        #"\bsimulators?\b.{0,40}\b(missing|not found|doesn't exist|does not exist)\b"#,
        #"\bmissing (the |an? )?([\w-]+ ){0,4}simulator"#,
        #"\bsimctl create\b"#,
        #"\b(make|create|add) (the |an? |one )?([\w-]+ ){0,4}simulator\b"#,
    ]
}

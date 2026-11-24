//
//  NominationStatePill.swift
//  Atlas
//

import SwiftUI

/// "Draft", "Submitted on Nov 20" or "Archived": only what the API says.
/// Nothing after submitting: Apple doesn't report back.
struct NominationStatePill: View {
    let nomination: Nomination

    var body: some View {
        Pill(text: Self.text(for: nomination), style: nomination.state == .archived ? .outline : .neutral)
            .fixedSize()
            .accessibilityIdentifier("nominations.state")
    }

    static func text(for nomination: Nomination) -> String {
        switch nomination.state {
        case .draft:
            return String(localized: "Draft", comment: "kind:pill")
        case .submitted:
            guard let date = nomination.submittedDate else { return String(localized: "Submitted", comment: "kind:pill") }
            return String(localized: "Submitted on \(date.formatted(.dateTime.month(.abbreviated).day()))", comment: "kind:pill")
        case .archived:
            return String(localized: "Archived", comment: "kind:pill")
        }
    }
}

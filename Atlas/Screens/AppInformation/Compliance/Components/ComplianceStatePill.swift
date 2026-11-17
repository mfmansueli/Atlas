//
//  ComplianceStatePill.swift
//  Atlas
//

import SwiftUI

/// Where a regulation stands, beside its name: the warning color while it
/// waits for the person, the accent once they've answered. A regulation
/// that passes has no pill.
struct ComplianceStatePill: View {
    let state: ComplianceItemState

    var body: some View {
        switch state {
        case .needsAnswer:
            Pill(text: String(localized: "Needs your answer"), style: .warning)
        case .toEnter:
            Pill(text: String(localized: "Enter in App Store Connect"), style: .accent)
        case .notPushed:
            Pill(text: String(localized: "Not pushed"), style: .accent)
        case .passes:
            EmptyView()
        }
    }
}

#Preview {
    VStack(alignment: .leading) {
        ComplianceStatePill(state: .needsAnswer)
        ComplianceStatePill(state: .toEnter)
        ComplianceStatePill(state: .notPushed)
    }
    .padding()
}

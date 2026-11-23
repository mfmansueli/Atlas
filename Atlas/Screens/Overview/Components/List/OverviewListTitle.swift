//
//  OverviewListTitle.swift
//  Atlas
//

import SwiftUI

/// A list's title on the Overview: "65 suggestions to review", "After
/// release". Title 3, semibold, a header for VoiceOver.
struct OverviewListTitle: View {
    let title: String
    let identifier: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(identifier)
    }
}

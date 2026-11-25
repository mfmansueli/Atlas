//
//  AutopilotBarNeedsYouPill.swift
//  Atlas
//

import SwiftUI

/// “Needs you”, filled purple: the one purple fill, while the assistant
/// waits for the person (README — Design system §1).
struct AutopilotBarNeedsYouPill: View {
    var body: some View {
        Text("Needs you", comment: "kind:pill")
            .atlasTextStyle(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Palette.aiFillLabel)
            .padding(.horizontal, Spacing.small)
            .frame(minHeight: Spacing.xLarge)
            .background(Palette.aiFill, in: Capsule())
            .fixedSize()
    }
}

#Preview {
    AutopilotBarNeedsYouPill().padding()
}

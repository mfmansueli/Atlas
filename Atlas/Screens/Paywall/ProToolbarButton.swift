//
//  ProToolbarButton.swift
//  Atlas
//

import SwiftUI

/// "Pro" in the toolbar while the person is on Free: opens the plans. As
/// tall as the toolbar's other buttons (`AutopilotButtonFace.height`).
struct ProToolbarButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Pro", systemImage: "sparkles")
                .labelStyle(.titleAndIcon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.medium)
                .frame(height: AutopilotButtonFace<EmptyView>.height)
                .background(PaywallStyle.gradient, in: Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .help("Upgrade to Atlas Pro")
        .accessibilityLabel(Text("Upgrade to Atlas Pro"))
        .accessibilityIdentifier("workspace.proButton")
    }
}

#Preview {
    ProToolbarButton {}.padding()
}

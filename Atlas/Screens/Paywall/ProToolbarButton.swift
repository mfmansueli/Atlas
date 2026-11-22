//
//  ProToolbarButton.swift
//  Atlas
//

import SwiftUI

/// "Pro" in the toolbar while the person is on Free: opens the plans. As
/// tall as the toolbar's other buttons (`AutopilotButtonFace.height`), and
/// glass like them.
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
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        // Liquid Glass like the toolbar's other buttons, tinted with the
        // paywall's violet as Review & Push's prominent glass is with the
        // accent color.
        .glassEffect(.regular.tint(PaywallStyle.brandBlue).interactive(), in: Capsule())
        .help("Upgrade to Atlas Pro")
        .accessibilityLabel(Text("Upgrade to Atlas Pro"))
        .accessibilityIdentifier("workspace.proButton")
    }
}

#Preview {
    ProToolbarButton {}.padding()
}

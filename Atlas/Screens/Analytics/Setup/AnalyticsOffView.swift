//
//  AnalyticsOffView.swift
//  Atlas
//

import SwiftUI

/// Analytics before it's turned on for an app: what it shows, what Apple
/// needs, and the one button that asks.
struct AnalyticsOffView: View {
    let appName: String
    let hasVendorNumber: Bool
    let isAsking: Bool
    var errorMessage: String?
    let onAsk: () -> Void
    let onAddVendorNumber: () -> Void

    var body: some View {
        VStack(spacing: Spacing.large) {
            MiniFunnel()
            Text("See where people drop off")
                .font(.title2.weight(.semibold))
            Text("Where people drop off between seeing \(appName) and paying, and what to fix.")
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)
            questions
            requirements
            if let errorMessage { InlineMessage.error(errorMessage) }
            Button(action: onAsk) {
                Text("Ask Apple for Reports").padding(.horizontal, Spacing.small)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAsking)
            .accessibilityIdentifier("analytics.askButton")
            Text("Asks Apple to start analytics reports for \(appName). Nothing else changes in App Store Connect. Stop anytime in Analytics settings.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.setup.off")
    }

    private var questions: some View {
        HStack(alignment: .top, spacing: Spacing.large) {
            question(String(localized: "Where do people drop off?"), String(localized: "Impression, page view, download, trial, paid."))
            question(String(localized: "Where is it worse than it should be?"), String(localized: "By country, language, source, device and product page."))
            question(String(localized: "What should I change next?"), String(localized: "Findings that open the right section."))
        }
        .frame(maxWidth: 620)
    }

    private func question(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.callout.weight(.semibold))
            Text(detail).font(.subheadline).foregroundStyle(Palette.label2)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var requirements: some View {
        VStack(spacing: 0) {
            requirement(String(localized: "An Admin key"), String(localized: "Apple checks when you ask"))
            Divider()
            requirement(String(localized: "One request to Apple, once per app"), String(localized: "The first reports arrive 1 to 2 days later"))
            Divider()
            HStack {
                Text("Vendor number, for trials and proceeds").font(.callout)
                Spacer(minLength: Spacing.small)
                if hasVendorNumber {
                    Label("Set", systemImage: "checkmark").font(.callout).foregroundStyle(Palette.label2)
                } else {
                    Button("Add Vendor Number…", action: onAddVendorNumber).controlSize(.regular)
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
        }
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5) }
        .frame(maxWidth: 560)
    }

    private func requirement(_ title: String, _ detail: String) -> some View {
        HStack {
            Text(title).font(.callout)
            Spacer(minLength: Spacing.small)
            Text(detail).font(.callout).foregroundStyle(Palette.label2)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AnalyticsOffView(appName: "Lumen Journal", hasVendorNumber: false, isAsking: false, onAsk: {}, onAddVendorNumber: {})
        .padding()
        .frame(width: 900, height: 620)
}

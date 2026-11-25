//
//  ReviewRiskRow.swift
//  Atlas
//

import SwiftUI

/// One App Review risk on the Overview: the section's symbol, the title
/// over the why, the level, then Show and Dismiss.
struct ReviewRiskRow: View {
    let risk: ReviewRisk
    let onShow: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        OverviewListRow(section: risk.check.section, title: risk.title, detail: risk.why) {
            Pill(text: risk.level.word, style: style)
                .fixedSize()
            Button(String(localized: "Show", comment: "kind:button · opens where an App Review risk is fixed"), action: onShow)
                .secondaryButton()
                .fixedSize()
                .accessibilityIdentifier("overview.reviewRisks.show.\(risk.id)")
            Button(String(localized: "Dismiss", comment: "kind:button · hides an App Review risk"), action: onDismiss)
                .plainButton()
                .fixedSize()
                .accessibilityIdentifier("overview.reviewRisks.dismiss.\(risk.id)")
        }
        .help(helpText)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityIdentifier("overview.reviewRisks.row.\(risk.id)")
    }

    private var style: PillStyle {
        switch risk.level {
        case .blocksReview: .danger
        case .likely: .warning
        case .check: .outline
        }
    }

    /// Guideline, evidence and fix, on hover.
    private var helpText: String {
        let places = risk.evidence.prefix(3).map { evidence in
            evidence.excerpt.isEmpty ? evidence.place : "\(evidence.place): “\(evidence.excerpt)”"
        }
        return ([String(localized: "Guideline \(risk.guideline)", comment: "kind:label · the App Review guideline a risk breaks")] + places + [risk.fix.advice])
            .joined(separator: "\n")
    }

    /// "Subscription terms, blocks review: Add a Terms of Use link. Guideline 3.1.2(c)."
    private var accessibilityText: String {
        String(
            localized: "\(risk.title), \(risk.level.word). \(risk.why) Guideline \(risk.guideline).",
            comment: "kind:accessibility-label · an App Review risk row"
        )
    }
}

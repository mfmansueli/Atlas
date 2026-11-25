//
//  StabilityBanner.swift
//  Atlas
//

import SwiftUI

/// Stability's amber banner while the newest version crashes clearly more
/// often (at least fairly sure): “**Version 1.4 crashes 3.2× as often as
/// 1.3,** mostly on iPhone 11. Pausing keeps it away from the other 95%.”,
/// with Open Version 1.4 and, while a phased release rolls out, Pause
/// Phased Release…, which always asks first.
struct StabilityBanner: View {
    let report: StabilityReport
    let actions: StabilityReleaseActions

    @State private var isConfirmingPause = false

    var body: some View {
        let text = StabilityAlertText.make(report, phase: actions.phase)
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.warnMark).accessibilityHidden(true)
            message(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.small) { buttons }
                VStack(alignment: .trailing, spacing: Spacing.xSmall) { buttons }
            }
            .controlSize(.regular)
            .fixedSize()
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.stability.alert")
        .confirmationDialog(
            String(localized: "Pause the phased release of \(report.latest.version)?", comment: "kind:sheet-title"),
            isPresented: $isConfirmingPause,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Pause Phased Release", comment: "kind:button"), action: actions.pause)
            Button(String(localized: "Cancel", comment: "kind:button"), role: .cancel) {}
        } message: {
            Text(String(
                localized: "The update stops reaching more people until you resume. Anyone can still download it. Pauses can total 30 days.",
                comment: "kind:sheet-body"
            ))
        }
    }

    @ViewBuilder
    private var buttons: some View {
        Button(String(localized: "Open Version \(report.latest.version)", comment: "kind:button"), action: actions.openVersion)
            .accessibilityIdentifier("analytics.stability.openVersion")
        if StabilityAlertText.canPause(actions.phase) {
            Button(String(localized: "Pause Phased Release…", comment: "kind:button")) { isConfirmingPause = true }
                .disabled(actions.isPausing)
                .accessibilityIdentifier("analytics.stability.pause")
        }
    }

    /// The bold lead, then the rest of the sentence.
    private func message(_ text: StabilityAlertText?) -> Text {
        let lead = Text(text?.lead ?? report.headline ?? "").fontWeight(.semibold)
        guard let detail = text?.detail else { return lead }
        return Text("\(lead) \(detail)")
    }
}

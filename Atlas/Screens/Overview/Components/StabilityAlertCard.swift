//
//  StabilityAlertCard.swift
//  Atlas
//

import SwiftUI

/// On the Overview while the newest version crashes clearly more often than
/// the one before (at least fairly sure): one amber banner (Redesign,
/// 23 November), “**Version 1.4 crashes 3.2× as often as 1.3,** mostly on
/// iPhone 11. Pausing keeps it away from the other 95%.”, with See
/// Stability and, while a phased release rolls out, Pause Phased
/// Release…, which always asks first. The version card shows the phased
/// release's days.
struct StabilityAlertCard: View {
    let report: StabilityReport
    /// The version's phased release; nil when it isn't rolling out in phases.
    let phase: ReleasePhase?
    let isPausing: Bool
    let onOpenStability: () -> Void
    let onPause: () -> Void

    @State private var isConfirmingPause = false

    var body: some View {
        let text = StabilityAlertText.make(report, phase: phase)
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.warnMark).accessibilityHidden(true)
            message(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .help(String(localized: "From a sample of people who share analytics with you.", comment: "kind:tooltip"))
            HStack(spacing: Spacing.small) {
                Button(String(localized: "See Stability", comment: "kind:button"), action: onOpenStability)
                    .accessibilityIdentifier("overview.stability.open")
                if StabilityAlertText.canPause(phase) {
                    Button("Pause Phased Release…") { isConfirmingPause = true }
                        .disabled(isPausing)
                        .accessibilityIdentifier("overview.stability.pause")
                }
            }
            .controlSize(.regular)
            .fixedSize()
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview.stability")
        .confirmationDialog(
            String(localized: "Pause the phased release of \(report.latest.version)?"),
            isPresented: $isConfirmingPause,
            titleVisibility: .visible
        ) {
            Button("Pause Phased Release", action: onPause)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
            The update stops reaching more people until you resume. Anyone can still download it. Pauses can total 30 days.
            """)
        }
    }

    /// The bold lead, then the rest of the sentence.
    private func message(_ text: StabilityAlertText?) -> Text {
        let lead = Text(text?.lead ?? report.headline ?? "").fontWeight(.semibold)
        guard let detail = text?.detail else { return lead }
        return Text("\(lead) \(detail)")
    }
}

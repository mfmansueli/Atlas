//
//  StabilityAlertCard.swift
//  Atlas
//

import SwiftUI

/// On the Overview while the newest version crashes clearly more often than
/// the one before (at least fairly sure): the numbers, where the phased
/// release stands, and Pause Phased Release…, which always asks first.
struct StabilityAlertCard: View {
    let report: StabilityReport
    /// The version's phased release; nil when it isn't rolling out in phases.
    let phase: ReleasePhase?
    let isPausing: Bool
    let onOpenStability: () -> Void
    let onPause: () -> Void

    @State private var isConfirmingPause = false

    private var phasedDay: (day: Int, isPaused: Bool)? {
        if case let .phased(day, isPaused) = phase { return (day, isPaused) }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.warningMark).accessibilityHidden(true)
                Text(report.headline ?? "").font(.headline).lineLimit(3)
                Spacer(minLength: Spacing.small)
            }
            Text(detail).font(.callout).foregroundStyle(Palette.label2).lineLimit(3)
            if let phasedDay {
                PhasedReleaseBars(day: phasedDay.day, isPaused: phasedDay.isPaused)
            }
            HStack(spacing: Spacing.small) {
                Spacer()
                Button("Open Stability", action: onOpenStability)
                    .accessibilityIdentifier("overview.stability.open")
                if let phasedDay, !phasedDay.isPaused {
                    Button("Pause Phased Release…") { isConfirmingPause = true }
                        .disabled(isPausing)
                        .accessibilityIdentifier("overview.stability.pause")
                }
            }
            .controlSize(.small)
        }
        .padding(Spacing.medium)
        .background(Palette.warningTint, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
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
            Text("Automatic updates stop reaching more people until you resume; anyone can still download it from the App Store. A release can stay paused for up to 30 days in all.")
        }
    }

    private var detail: String {
        var parts: [String] = []
        if let new = report.latest.perThousand, let old = report.previous?.perThousand {
            parts.append(String(localized: "\(AnalyticsText.perThousand(new)) crashes per 1,000 sessions against \(AnalyticsText.perThousand(old))"))
        }
        if let device = report.mostAffected { parts.append(String(localized: "most on \(device.device)")) }
        parts.append(String(localized: "a sample of people who share analytics"))
        return parts.joined(separator: " · ")
    }
}

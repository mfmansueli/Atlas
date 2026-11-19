//
//  ReviewPushToolbarButton.swift
//  Atlas
//

import SwiftUI

/// "Review & Push" with the number of pending changes and planned images
/// across all apps: prominent glass while anything is waiting (⇧⌘P). While
/// a push runs, its arrow keeps rising and the badge says how many were
/// sent, so the sheet can be minimized; a click opens the progress again.
struct ReviewPushToolbarButton: View {
    let count: Int
    /// Sent and total while a push runs; nil otherwise.
    var sending: (sent: Int, total: Int)?
    /// Icon and count only, when the toolbar is out of room.
    var isCompact = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if count > 0 || sending != nil {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.glass)
        }
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isCompact {
                    label.labelStyle(.iconOnly)
                } else {
                    label.labelStyle(.titleAndIcon)
                }
                if let badge {
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.white.opacity(0.25), in: Capsule())
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("workspace.reviewPushBadge")
                }
            }
        }
        .help(help)
        .accessibilityLabel(Text("Review & Push"))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityIdentifier("workspace.reviewPushButton")
    }

    @ViewBuilder
    private var label: some View {
        let isSending = sending != nil
        if reduceMotion {
            Label("Review & Push", systemImage: "arrow.up.circle")
                .symbolEffect(.pulse, options: .repeat(.continuous), isActive: isSending)
        } else {
            Label("Review & Push", systemImage: "arrow.up.circle")
                .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.4)), isActive: isSending)
        }
    }

    /// "15/87" while sending, else the pending count.
    private var badge: String? {
        if let sending { return "\(sending.sent)/\(sending.total)" }
        return count > 0 ? count.formatted() : nil
    }

    private var help: String {
        guard let sending else { return String(localized: "Review & Push (⇧⌘P)") }
        return String(localized: "Pushing · \(sending.sent) of \(sending.total) sent. Click to see the progress (⇧⌘P).")
    }

    private var accessibilityValue: String {
        if let sending { return String(localized: "Pushing, \(sending.sent) of \(sending.total) sent") }
        return count == 1 ? String(localized: "1 pending change") : String(localized: "\(count) pending changes")
    }
}

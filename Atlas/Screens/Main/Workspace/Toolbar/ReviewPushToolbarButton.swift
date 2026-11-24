//
//  ReviewPushToolbarButton.swift
//  Atlas
//

import SwiftUI

/// "Review & Push" with the number of pending changes and planned images
/// across all apps: prominent glass while anything is waiting (⇧⌘P), plain
/// glass reading “Up to Date” when nothing is. It's the only way to push:
/// no page has a push button of its own. While
/// a push runs, its arrow keeps rising and the badge says how many were
/// sent, so the sheet can be minimized; a click opens the progress again.
/// Something accepted joining it makes the arrow bounce once (board 57: the
/// toast says it's waiting here, top right).
struct ReviewPushToolbarButton: View {
    let count: Int
    /// Sent and total while a push runs; nil otherwise.
    var sending: (sent: Int, total: Int)?
    /// Icon and count only, when the toolbar is out of room.
    var isCompact = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped when changes join; the arrow bounces once each time.
    @State private var arrivals = 0

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
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.white.opacity(0.25), in: Capsule())
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("workspace.reviewPushBadge")
                }
            }
        }
        .onChange(of: count) { old, new in
            if Self.bounces(from: old, to: new, isSending: sending != nil) { arrivals += 1 }
        }
        .help(help)
        // Its label folds and unfolds, the badge grows to “12/40”.
        .toolbarItemFit([AnyHashable(isCompact), AnyHashable(isUpToDate), AnyHashable(badge)])
        .accessibilityLabel(Text("Review & Push"))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityIdentifier("workspace.reviewPushButton")
    }

    /// Nothing queued and nothing sending.
    private var isUpToDate: Bool { count == 0 && sending == nil }

    @ViewBuilder
    private var label: some View {
        let isSending = sending != nil
        if isUpToDate {
            Label("Up to Date", systemImage: "checkmark.circle")
        } else if reduceMotion {
            Label("Review & Push", systemImage: "arrow.up.circle")
                .symbolEffect(.pulse, options: .repeat(.continuous), isActive: isSending)
        } else {
            Label("Review & Push", systemImage: "arrow.up.circle")
                .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.4)), isActive: isSending)
                .symbolEffect(.bounce.up, value: arrivals)
        }
    }

    /// More waiting than before, and not because a push is running: what
    /// was just accepted has joined.
    nonisolated static func bounces(from old: Int, to new: Int, isSending: Bool) -> Bool {
        new > old && !isSending
    }

    /// "15/87" while sending, else the pending count.
    private var badge: String? {
        if let sending { return "\(sending.sent)/\(sending.total)" }
        return count > 0 ? count.formatted() : nil
    }

    private var help: String {
        guard let sending else { return String(localized: "Review & Push (⇧⌘P)") }
        return String(localized: "Pushing · \(sending.sent) of \(sending.total) sent. Click for progress (⇧⌘P).")
    }

    private var accessibilityValue: String {
        if let sending { return String(localized: "Pushing \(sending.sent) of \(sending.total)") }
        if isUpToDate { return String(localized: "Up to date") }
        return count == 1 ? String(localized: "1 change ready") : String(localized: "\(count) changes ready")
    }
}

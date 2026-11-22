//
//  AutoReplyStrip.swift
//  Atlas
//

import SwiftUI

/// At the top of Reviews while Reply Automatically is on (board 58 · 3 and
/// 6): the rule, the next check, Pause or Resume, History and Settings….
/// It says why replies keep waiting (no reply sent by hand yet, the day's
/// cap) and why none could be written (Claude Code isn't connected).
struct AutoReplyStrip: View {
    let rule: AutoReplyRule
    /// When the menu bar checks next; nil while background work is paused.
    var nextCheck: Date?
    /// Why due replies wait.
    var hold: String?
    /// Why replies couldn't be written.
    var writeProblem: String?
    let historyCount: Int
    let onPause: (Bool) -> Void
    let onHistory: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Circle()
                    .fill(rule.isPaused ? Palette.label3 : Palette.positive)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .accessibilityIdentifier("autoReply.strip.title")
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("autoReply.strip.detail")
                }
                .layoutPriority(1)
                Spacer(minLength: Spacing.medium)
                HStack(spacing: Spacing.small) {
                    Button(rule.isPaused ? String(localized: "Resume") : String(localized: "Pause")) { onPause(!rule.isPaused) }
                        .accessibilityIdentifier("autoReply.strip.pause")
                    if historyCount > 0 {
                        Button(action: onHistory) {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }
                        .accessibilityIdentifier("autoReply.strip.history")
                    }
                    Button("Settings…", action: onSettings)
                        .accessibilityIdentifier("autoReply.strip.settings")
                }
                .controlSize(.small)
                .buttonBorderShape(.capsule)
                .fixedSize()
            }
            ForEach([hold, writeProblem].compactMap(\.self), id: \.self) { line in
                Label(line, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(Palette.warningMark)
                    .padding(.leading, 16)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("autoReply.strip")
    }

    private var title: String {
        rule.isPaused ? String(localized: "Auto-reply is paused") : String(localized: "Replying automatically")
    }

    /// The rule and the next check, or what pausing does.
    private var detail: String {
        if rule.isPaused { return String(localized: "New reviews are drafted and wait for you until you resume.") }
        // A check that's due runs within the next tick: say nothing then.
        guard let nextCheck, nextCheck > .now.addingTimeInterval(60) else { return rule.summary }
        let check = String(localized: "next check \(nextCheck.formatted(.relative(presentation: .named)))")
        return "\(rule.summary) · \(check)"
    }
}

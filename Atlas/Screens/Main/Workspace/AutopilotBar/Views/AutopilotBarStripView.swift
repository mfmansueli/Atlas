//
//  AutopilotBarStripView.swift
//  Atlas
//

import SwiftUI

/// The strip the closed bar grows above its field when something happens
/// (board 80). Working: the ✦ breathes and the step's text sweeps (the one
/// loop on screen), with its count, a bar that moves one counted unit at a
/// time, and Stop. Needs you: the question with its answers as buttons and
/// the purple “Needs you”. Stopped: amber, the reason and Try Again. Done:
/// one line, Show and ✕. Reduce Motion keeps it all still (the DesignSystem's
/// modifiers read it).
struct AutopilotBarStripView: View {
    let strip: AutopilotBarStrip
    let onAction: () -> Void
    let onChoice: (String) -> Void
    let onStop: () -> Void
    let onDismiss: () -> Void

    /// Lines under the first start under its words, past the lead mark.
    private static let indent = Metrics.chatLeadSize + Spacing.small

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                lead
                Text(strip.title)
                    .atlasTextStyle(.body)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .aiSweep(strip.kind == .working)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if strip.kind == .needsYou { AutopilotBarNeedsYouPill() }
                if let detail = strip.detail {
                    Text(detail)
                        .atlasTextStyle(.callout)
                        .foregroundStyle(Palette.label2)
                        .monospacedDigit()
                        .fixedSize()
                }
                if let title = strip.actionTitle {
                    Button(title, action: onAction)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .fixedSize()
                        .accessibilityIdentifier("autopilotBar.strip.action")
                }
                if strip.canStop { stopButton }
                if strip.canDismiss { dismissButton }
            }
            if let subtitle = strip.subtitle {
                Text(subtitle)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, Self.indent)
                    .accessibilityIdentifier("autopilotBar.strip.subtitle")
            }
            if let progress = strip.progress {
                AIProgressBar(value: progress, height: Spacing.xxSmall)
                    .padding(.leading, Self.indent)
            }
            if !strip.choices.isEmpty {
                FlowLayout(spacing: Spacing.xSmall) {
                    ForEach(strip.choices, id: \.self) { choice in
                        Button(choice) { onChoice(choice) }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .accessibilityIdentifier("autopilotBar.strip.choice")
                    }
                }
                .padding(.leading, Self.indent)
            }
        }
        .padding(.leading, Spacing.medium)
        .padding(.trailing, Spacing.small)
        .padding(.top, Spacing.small)
        .padding(.bottom, Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Needing the person, it nudges once (effect 5).
        .aiNeedsYou(strip.kind == .needsYou)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(strip.accessibilityLabel))
        .accessibilityIdentifier("autopilotBar.strip")
    }

    private var lead: some View {
        Group {
            switch strip.kind {
            case .working:
                Image(systemName: "sparkles").foregroundStyle(Palette.ai).aiBreathing(true)
            case .needsYou:
                Image(systemName: "sparkles").foregroundStyle(Palette.ai)
            case .done:
                Image(systemName: "checkmark").foregroundStyle(Palette.ok)
            case .stopped:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.warnMark)
            }
        }
        .frame(width: Metrics.chatLeadSize, height: Metrics.chatLeadSize)
        .accessibilityHidden(true)
    }

    private var stopButton: some View {
        Button(action: onStop) {
            Image(systemName: "stop.fill")
                .imageScale(.small)
                .foregroundStyle(Palette.label)
                .frame(width: Metrics.chatButtonSize, height: Metrics.chatButtonSize)
                .background(Palette.fill2, in: Circle())
        }
        .buttonStyle(.plain)
        .help(Text("Stop", comment: "kind:tooltip"))
        .accessibilityLabel(Text("Stop", comment: "kind:accessibility"))
        .accessibilityIdentifier("autopilotBar.stop")
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .imageScale(.small)
                .foregroundStyle(Palette.label2)
                .frame(width: Metrics.chatButtonSize, height: Metrics.chatButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text("Dismiss", comment: "kind:tooltip"))
        .accessibilityLabel(Text("Dismiss", comment: "kind:accessibility"))
        .accessibilityIdentifier("autopilotBar.dismiss")
    }
}

#Preview {
    VStack(spacing: Spacing.medium) {
        AutopilotBarStripView(
            strip: AutopilotBarStrip(
                kind: .working, source: .ask, key: "a", title: "Read store page…", detail: "2 of 3",
                subtitle: "“Suggest Texts · Store Page · German” · they show up in purple", progress: 1.0 / 3, canStop: true
            ),
            onAction: {}, onChoice: { _ in }, onStop: {}, onDismiss: {}
        )
        AutopilotBarStripView(
            strip: AutopilotBarStrip(
                kind: .needsYou, source: .chat, key: "b", title: "Count every product, or only subscriptions?",
                choices: ["Only Subscriptions", "Every Product"]
            ),
            onAction: {}, onChoice: { _ in }, onStop: {}, onDismiss: {}
        )
    }
    .frame(width: Metrics.autopilotBarWidth)
    .padding()
}

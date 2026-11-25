//
//  ReviewPushPillFace.swift
//  Atlas
//

import SwiftUI

/// How Review & Push at the bottom looks (board 80): a 44 pt Liquid Glass
/// capsule beside the Autopilot bar, plain reading “Up to Date”, tinted
/// blue with the count while changes wait, “Pushing · 14 of 23” while a
/// push runs. It pulses as an accepted change lands on it
/// (`PushLandingEffect`). `ReviewPushPill` gives it what it shows; DEBUG
/// scenes show each state on its own.
struct ReviewPushPillFace: View {
    let state: ReviewPushPillState
    /// Its icon and count only.
    var isCompact = false
    /// Goes up as each flight lands.
    var landings = 0
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let badge = state.badge(isCompact: isCompact)
        Button(action: action) {
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: "arrow.up.circle")
                    .imageScale(.large)
                    .accessibilityHidden(true)
                if !isCompact {
                    Text(state.title)
                        .lineLimit(1)
                        .contentTransition(reduceMotion ? .identity : .numericText(value: Double(state.count)))
                }
                if let badge {
                    badgeView(badge)
                }
            }
            .atlasTextStyle(.headline)
            .foregroundStyle(state.isProminent ? Color.white : Palette.label)
            .padding(.leading, Spacing.medium)
            .padding(.trailing, badge == nil ? Spacing.medium : Spacing.small)
            .frame(height: Metrics.reviewPushPillHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background { surface }
        .modifier(PushLandingEffect(landings: landings))
        .fixedSize()
        .help(state.help)
        .accessibilityLabel(Text("Review & Push", comment: "kind:button"))
        .accessibilityValue(Text(state.accessibilityValue))
        .accessibilityIdentifier("workspace.reviewPushButton")
    }

    private func badgeView(_ text: String) -> some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText(value: Double(state.count)))
            .padding(.horizontal, Spacing.xSmall)
            .frame(minWidth: Metrics.reviewPushBadgeSize, minHeight: Metrics.reviewPushBadgeSize)
            .background(state.isProminent ? Color.white.opacity(0.24) : Palette.fill2, in: Capsule())
            .accessibilityIdentifier("workspace.reviewPushBadge")
    }

    /// Liquid Glass you see the page through, tinted with the see-through
    /// accent while something waits; solid with Reduce Transparency.
    @ViewBuilder
    private var surface: some View {
        if reduceTransparency {
            Capsule()
                .fill(state.isProminent ? Palette.accent : Palette.raised)
                .overlay { Capsule().strokeBorder(Palette.separator, lineWidth: 0.5) }
        } else {
            Capsule()
                .fill(.clear)
                .glassEffect(state.isProminent ? .regular.tint(Palette.accentGlass).interactive() : .regular.interactive(), in: Capsule())
        }
    }
}

#Preview {
    HStack(alignment: .bottom, spacing: Spacing.small) {
        ReviewPushPillFace(state: .upToDate) {}
        ReviewPushPillFace(state: .pending(3)) {}
        ReviewPushPillFace(state: .pushing(sent: 14, total: 23)) {}
        ReviewPushPillFace(state: .pending(3), isCompact: true) {}
    }
    .padding(Spacing.xxLarge)
}

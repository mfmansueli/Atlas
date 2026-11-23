//
//  AutopilotButtonFace.swift
//  Atlas
//

import SwiftUI

/// How the Autopilot split button looks: the main half with the animated
/// label, a hairline, and the arrow's menu, on a Liquid Glass capsule
/// (tinted purple while the run needs the person). While it works a light runs
/// along the capsule's edge and a 2 pt bar shows counted progress; when a
/// run is done the button bounces once. The toolbar button adds what it
/// does; DEBUG scenes show every look.
struct AutopilotButtonFace<MenuContent: View>: View {
    let look: AutopilotButtonLook
    var title: String?
    var isPro = false
    var isCompact = false
    /// Bumped when a run is done: one bounce.
    var doneCount = 0
    /// What VoiceOver says for the main half.
    var accessibilityLabel = ""
    let onMain: () -> Void
    @ViewBuilder let menu: () -> MenuContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        split
            .background { glass }
            .overlay(alignment: .bottomLeading) { progressLine }
            .overlay {
                if look.isWorking { AutopilotEdgeLight() }
            }
            .keyframeAnimator(initialValue: 1.0, trigger: doneCount) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                // One small bounce, 0.45 s; none with Reduce Motion.
                CubicKeyframe(bounces ? 1.07 : 1, duration: 0.2)
                CubicKeyframe(1, duration: 0.25)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: look)
    }

    /// The toolbar's other buttons' height: Review & Push's prominent glass
    /// and the large Refresh and Activity group.
    static var height: CGFloat { 36 }

    private var split: some View {
        HStack(spacing: 0) {
            Button(action: onMain) {
                AutopilotButtonLabel(look: look, title: title, isPro: isPro, isCompact: isCompact)
                    .padding(.leading, 12)
                    .padding(.trailing, 10)
                    .frame(height: Self.height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityIdentifier("workspace.autopilot.main")
            Rectangle()
                .fill(isNeedingYou ? Color.white.opacity(0.35) : Palette.separator)
                .frame(width: 0.5, height: 18)
                .accessibilityHidden(true)
            Menu {
                menu()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isNeedingYou ? Color.white : Palette.label2)
                    .frame(width: 30, height: Self.height)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(Text("More Autopilot actions"))
            .accessibilityIdentifier("workspace.autopilot.more")
        }
    }

    /// Liquid Glass, tinted purple while the run needs the person.
    private var glass: some View {
        Capsule()
            .fill(.clear)
            .glassEffect(glassStyle, in: Capsule())
    }

    private var glassStyle: Glass {
        isNeedingYou ? .clear.tint(Palette.aiFill.opacity(0.6)).interactive() : .regular.interactive()
    }

    /// Inside the bottom of the main half, while a run counts its steps.
    @ViewBuilder
    private var progressLine: some View {
        if let progress = look.progress {
            AutopilotProgressLine(value: progress)
                .padding(.leading, 12)
                .padding(.trailing, 36)
                .padding(.bottom, 3)
        }
    }

    private var bounces: Bool {
        !reduceMotion && doneCount > 0
    }

    private var isNeedingYou: Bool {
        if case .needsYou = look { return true }
        return false
    }
}

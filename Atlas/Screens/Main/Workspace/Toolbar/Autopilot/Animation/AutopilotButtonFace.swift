//
//  AutopilotButtonFace.swift
//  Atlas
//

import SwiftUI

/// How the Autopilot split button looks: the main half with its label, a
/// hairline, and the arrow's menu, on a Liquid Glass capsule (filled
/// purple while the run needs the person). Motion v2 (README — Design
/// system §7): while it works nothing runs round it; the spark is still and
/// a bar shows counted progress in steps with its soft sweep (effect 2);
/// starting to need the person it nudges once (effect 5). The toolbar
/// button adds what it does; DEBUG scenes show every look.
struct AutopilotButtonFace<MenuContent: View>: View {
    let look: AutopilotButtonLook
    var title: String?
    var isPro = false
    var isCompact = false
    /// What VoiceOver says for the main half.
    var accessibilityLabel = ""
    let onMain: () -> Void
    @ViewBuilder let menu: () -> MenuContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        split
            .background { glass }
            .overlay(alignment: .bottomLeading) { progressLine }
            .aiNeedsYou(look.isNeedingYou)
            .animation(reduceMotion ? nil : MotionTiming.base.animation, value: look)
            // In the toolbar, the item takes the width of what it says now,
            // as runs start, need the person and end.
            .toolbarItemFit([AnyHashable(look), AnyHashable(title), AnyHashable(isPro), AnyHashable(isCompact)])
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
                .fill(look.isNeedingYou ? Color.white.opacity(0.35) : Palette.separator)
                .frame(width: 0.5, height: 18)
                .accessibilityHidden(true)
            Menu {
                menu()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(look.isNeedingYou ? Color.white : Palette.label2)
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

    /// Liquid Glass, tinted purple (aiFill) while the run needs the person:
    /// the one purple fill.
    private var glass: some View {
        Capsule()
            .fill(.clear)
            .glassEffect(glassStyle, in: Capsule())
    }

    private var glassStyle: Glass {
        look.isNeedingYou ? .clear.tint(Palette.aiFill.opacity(0.6)).interactive() : .regular.interactive()
    }

    /// Inside the bottom of the main half, while a run counts its steps.
    @ViewBuilder
    private var progressLine: some View {
        if let progress = look.progress {
            AIProgressBar(value: progress)
                .padding(.leading, 12)
                .padding(.trailing, 36)
                .padding(.bottom, 2)
        }
    }
}

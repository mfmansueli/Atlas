//
//  NewArrivalsBelowNotice.swift
//  Atlas
//

import SwiftUI

/// “3 new below” (effect 3, Arrived): suggestions that landed out of sight
/// appear still, and this small notice at the bottom of the page says how
/// many wait further down until they're scrolled to. Clicking it puts it
/// away. It slides up 4 pt as it comes; with Reduce Motion it fades.
struct NewArrivalsBelowNotice: View {
    var offScreen: ArrivalsOffScreen = .shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if offScreen.count > 0 {
                Button {
                    offScreen.removeAll()
                } label: {
                    Label(Self.text(count: offScreen.count), systemImage: "arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ai)
                        .padding(.horizontal, Spacing.medium)
                        .padding(.vertical, Spacing.xSmall)
                        .background(Palette.raised, in: Capsule())
                        .overlay(Capsule().strokeBorder(Palette.aiEdge, lineWidth: 1))
                        .depth(.card)
                }
                .buttonStyle(.plain)
                .help(Text("Scroll down to see them."))
                .accessibilityIdentifier("motion.newBelow")
                .transition(reduceMotion ? .opacity : .offset(y: 4).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? MotionTiming.fast.animation : MotionTiming.base.animation, value: offScreen.count > 0)
    }

    /// “1 new below”, “3 new below”.
    static func text(count: Int) -> String {
        String(localized: "\(count) new below", comment: "kind:pill")
    }
}

#Preview {
    let offScreen = ArrivalsOffScreen()
    offScreen.add("a")
    offScreen.add("b")
    offScreen.add("c")
    return NewArrivalsBelowNotice(offScreen: offScreen)
        .padding()
}

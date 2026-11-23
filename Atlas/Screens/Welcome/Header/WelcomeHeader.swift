//
//  WelcomeHeader.swift
//  Atlas
//

import SwiftUI

/// The top of the welcome screens (board 45): the icon's own blue with
/// the mark alive in it and, on the large header, languages with their
/// flags (and now and then a price) appearing and changing round the
/// globe. Connect uses the compact header (the mark alone); Reading your
/// apps the large one at double speed. With Reduce Motion it's the still
/// icon with eight languages round it: nothing travels, turns or changes.
struct WelcomeHeader: View {
    enum Style: Hashable, Sendable {
        case large
        case compact
    }

    var style: Style = .large
    /// The mark's side, from the window's height.
    var markSize: CGFloat = 300
    /// 2 while Atlas reads the apps.
    var pace: Double = 1
    /// DEBUG scenes show the Reduce Motion header without the setting.
    var forcesStill = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    /// The icon's light gradient, top to bottom, in either appearance.
    nonisolated static let gradient = AtlasIconGradient.light

    private var isStill: Bool { reduceMotion || forcesStill }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: isStill)) { timeline in
                content(time: isStill ? 0 : timeline.date.timeIntervalSince(start), size: geometry.size)
            }
        }
        .background(LinearGradient(colors: Self.gradient, startPoint: .top, endPoint: .bottom))
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("welcome.header")
    }

    private func content(time: TimeInterval, size: CGSize) -> some View {
        let motion = WelcomeMotion(time: time, pace: pace)
        return ZStack {
            RadialGradient(
                colors: [.white.opacity(0.32), .white.opacity(0)],
                center: UnitPoint(x: 0.5, y: 0.46), startRadius: 0, endRadius: 380
            )
            if style == .large {
                chips(time: time, size: size)
            }
            WelcomeMark(motion: motion, isStill: isStill)
                .frame(width: markSize, height: markSize)
                .offset(y: isStill ? 0 : motion.floatOffset)
        }
        .frame(width: size.width, height: size.height)
    }

    private func chips(time: TimeInterval, size: CGSize) -> some View {
        let slots = WelcomeChipSlot.all.filter { !$0.isFar || size.width >= WelcomeChipSlot.farMinimumWidth }
        return ForEach(slots) { slot in
            WelcomeChipSlotView(slot: slot, time: time, pace: pace, isStill: isStill)
                .position(x: size.width * slot.x, y: size.height * slot.y + (isStill ? 0 : slot.drift(at: time)))
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    WelcomeHeader()
        .frame(width: 1200, height: 400)
}

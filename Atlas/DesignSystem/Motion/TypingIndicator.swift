//
//  TypingIndicator.swift
//  Atlas
//

import SwiftUI

/// AI motion 7, "Assistant is typing" (README — Design System §7): three
/// dots in a purple-tinted bubble, a 1.2 s loop, while an assistant writes
/// (Connect's hello, a reply being drafted). The bubble grows from 0.96 to
/// full size in 0.25 s as it appears. With Reduce Motion it's a still "…".
/// VoiceOver reads `label`.
struct TypingIndicator: View {
    var label: String = .init(localized: "Writing…")

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    /// One pass of the three dots.
    static let loop: TimeInterval = 1.2

    var body: some View {
        content
            .frame(height: 16)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Palette.aiSurface, in: Self.bubble)
            .overlay(Self.bubble.strokeBorder(Palette.aiEdge, lineWidth: 1))
            .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.96, anchor: .topLeading)
            .onAppear {
                withAnimation(.easeOut(duration: 0.25)) { hasAppeared = true }
            }
            .accessibilityElement()
            .accessibilityLabel(Text(label))
            .accessibilityIdentifier("motion.typing")
    }

    @ViewBuilder
    private var content: some View {
        if reduceMotion {
            Text(verbatim: "…")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.ai)
        } else {
            TimelineView(.animation) { context in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.loop) / Self.loop
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        let lift = Self.lift(phase: phase, dot: index)
                        Circle()
                            .fill(Palette.aiMark)
                            .frame(width: 6, height: 6)
                            .opacity(0.35 + 0.65 * lift)
                            .offset(y: -2 * lift)
                    }
                }
            }
        }
    }

    /// How far dot `dot` is up at `phase` (0–1 of the loop): each rises and
    /// falls in turn, 0.2 of the loop apart.
    static func lift(phase: Double, dot: Int) -> Double {
        let local = (phase - Double(dot) * 0.2).truncatingRemainder(dividingBy: 1)
        let wrapped = local < 0 ? local + 1 : local
        guard wrapped < 0.4 else { return 0 }
        return sin(wrapped / 0.4 * .pi)
    }

    /// The design's message bubble: square where it points at the sender.
    static let bubble = UnevenRoundedRectangle(
        topLeadingRadius: 4, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous
    )
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        TypingIndicator()
    }
    .padding()
}

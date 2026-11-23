//
//  AcceptCheckMark.swift
//  Atlas
//

import SwiftUI

/// The check an accepted suggestion shows while it settles: a white stroke
/// that draws itself in 0.3 s on the accent circle (board 64's `acc-k`).
/// The circle only fades in; blue never moves.
struct AcceptCheckMark: View {
    @State private var drawn: CGFloat = 0
    @State private var isShown = false

    var body: some View {
        ZStack {
            Circle().fill(Palette.accent)
            Check()
                .trim(from: 0, to: drawn)
                .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 12, height: 12)
        }
        .frame(width: 18, height: 18)
        .opacity(isShown ? 1 : 0)
        .onAppear {
            withAnimation(MotionTiming.base.animation) { isShown = true }
            withAnimation(AIDecided.checkDraw) { drawn = 1 }
        }
        .accessibilityHidden(true)
    }

    /// The board's tick, on a 16 pt grid: down to the corner, then up.
    private struct Check: Shape {
        nonisolated func path(in rect: CGRect) -> Path {
            let scale = min(rect.width, rect.height) / 16
            var path = Path()
            path.move(to: CGPoint(x: rect.minX + 3.5 * scale, y: rect.minY + 8.4 * scale))
            path.addLine(to: CGPoint(x: rect.minX + 6.5 * scale, y: rect.minY + 11.4 * scale))
            path.addLine(to: CGPoint(x: rect.minX + 12.5 * scale, y: rect.minY + 4.8 * scale))
            return path
        }
    }
}

#Preview {
    AcceptCheckMark()
        .padding()
}

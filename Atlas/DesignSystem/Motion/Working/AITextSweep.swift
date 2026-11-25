//
//  AITextSweep.swift
//  Atlas
//

import SwiftUI

/// Effect 2 · Working, on the words of the step being worked on (README —
/// Design system §7, v2, the chat button): one purple band passes over the
/// text, then pauses: 2.8 s a pass (motion.sweep), in time with the
/// progress bar's sweep (`AIProgressBar.sweep(at:)`), so the pill has one
/// loop. Still working, without faking progress. With Reduce Motion the
/// text stays as it is.
struct AITextSweep: ViewModifier {
    let isSweeping: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The band's share of the text's width.
    nonisolated static let bandShare: CGFloat = 0.35

    func body(content: Content) -> some View {
        content.overlay {
            if Self.sweeps(isSweeping, reduceMotion: reduceMotion) {
                TimelineView(.animation) { context in
                    let sweep = AIProgressBar.sweep(at: context.date.timeIntervalSinceReferenceDate)
                    GeometryReader { proxy in
                        let band = proxy.size.width * Self.bandShare
                        LinearGradient(colors: [Palette.ai.opacity(0), Palette.ai, Palette.ai.opacity(0)], startPoint: .leading, endPoint: .trailing)
                            .frame(width: band, height: proxy.size.height)
                            .offset(x: Self.position(of: sweep.offset) * (proxy.size.width + band) - band)
                            .opacity(sweep.opacity)
                    }
                }
                // Only the letters take the band.
                .mask { content }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }

    /// Only work that runs sweeps, and never with Reduce Motion.
    nonisolated static func sweeps(_ isSweeping: Bool, reduceMotion: Bool) -> Bool {
        isSweeping && !reduceMotion
    }

    /// The bar's sweep offset (−1 to 1.2 of its band) as 0–1 across the
    /// text: off the left edge to off the right one.
    nonisolated static func position(of offset: Double) -> CGFloat {
        CGFloat(min(max((offset + 1) / 2.2, 0), 1))
    }
}

extension View {
    /// Effect 2 on the text of the step being worked on; see `AITextSweep`.
    func aiSweep(_ isSweeping: Bool) -> some View {
        modifier(AITextSweep(isSweeping: isSweeping))
    }
}

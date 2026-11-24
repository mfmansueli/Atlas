//
//  TourTipViewStyle.swift
//  Atlas
//

import SwiftUI
import TipKit

/// Draws the tour's tips in their popovers (board 63): the glyph on a
/// tinted tile, title and text, Next (Done) and Skip the Tour (Connect an
/// Assistant…) beside "2 of 5", and a close button. Next invalidates the
/// tip it closes; Skip the Tour and the close button invalidate it too, and
/// the tour then shows no other.
struct TourTipViewStyle: TipViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        if let tip = configuration.tip as? TourTip {
            TourTipView(step: tip.step) {
                tip.onNext()
                tip.invalidate(reason: .actionPerformed)
            } onAlternative: {
                tip.onAlternative()
                tip.invalidate(reason: .actionPerformed)
            } onClose: {
                tip.onClose()
                tip.invalidate(reason: .tipClosed)
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                configuration.title?.font(.body.weight(.semibold))
                configuration.message?.font(.callout).foregroundStyle(Palette.label2)
            }
            .padding(14)
        }
    }
}

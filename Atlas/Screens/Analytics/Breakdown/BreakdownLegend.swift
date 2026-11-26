//
//  BreakdownLegend.swift
//  Atlas
//

import SwiftUI

/// What the table's marks mean, once, in its footer (board 92): against
/// the app's average, better, worse or about the same; how sure; and the
/// counts shown when there are too few to tell.
struct BreakdownLegend: View {
    let appName: String

    var body: some View {
        FlowLayout(spacing: Spacing.xSmall) {
            Text("Against \(appName)’s average:", comment: "kind:label · Break It Down legend")
            mark(RateStanding.better.systemImage, tint: Palette.label2)
            Text("better", comment: "kind:label · Break It Down legend")
            mark(RateStanding.worse.systemImage, tint: Palette.warn)
            Text("worse", comment: "kind:label · Break It Down legend")
            mark(RateStanding.same.systemImage, tint: Palette.label2)
            Text("about the same ·", comment: "kind:label · Break It Down legend")
            ConfidenceMeter(bars: 2)
            Text("how sure ·", comment: "kind:label · Break It Down legend")
            Text("“3 of 40”", comment: "kind:label · Break It Down legend, an example of counts")
                .foregroundStyle(Palette.label3)
            Text("too few to tell", comment: "kind:label · Break It Down legend")
        }
        .atlasTextStyle(.subheadline)
        .foregroundStyle(Palette.label2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("analytics.breakdown.legend")
    }

    private func mark(_ systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .atlasTextStyle(.footnote)
            .foregroundStyle(tint)
    }
}

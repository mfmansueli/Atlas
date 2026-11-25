//
//  PriceTestPill.swift
//  Atlas
//

import SwiftUI

/// "Price test" beside a product's name in the product list and on its
/// page (board 76, `pt-run-list`), its region, day and end date in the
/// tooltip. Grey: a state, not an action; no motion.
struct PriceTestPill: View {
    let tip: String

    var body: some View {
        Pill(text: String(localized: "Price test", comment: "kind:pill"), systemImage: "flask")
            .fixedSize()
            .help(Text(verbatim: tip))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Price test: \(tip)", comment: "kind:accessibility-label"))
            .accessibilityIdentifier("pricing.priceTestPill")
    }
}

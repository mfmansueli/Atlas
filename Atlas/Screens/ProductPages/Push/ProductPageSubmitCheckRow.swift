//
//  ProductPageSubmitCheckRow.swift
//  Atlas
//

import SwiftUI

/// One line of "What goes to Apple": a tick, or a warning mark where Atlas
/// found something App Review may stop.
struct ProductPageSubmitCheckRow: View {
    let check: ProductPageSubmitCheck

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: check.isFine ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(check.isFine ? Palette.decrease : Palette.warningMark)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(check.title)
                    .font(.callout.weight(.medium))
                Text(check.detail)
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // Title and detail in one label: combined, or as a value, macOS
        // reads only the title.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(check.title). \(check.detail)"))
        .accessibilityIdentifier("pages.submit.check.\(check.id)")
    }
}

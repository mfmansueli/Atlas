//
//  VersionCheckRow.swift
//  Atlas
//

import SwiftUI

/// One thing App Review still needs: a mark, what it is, a detail, and the
/// button that fixes it (Review, Open).
struct VersionCheckRow: View {
    let check: ReleaseCheck
    let action: () -> Void

    var body: some View {
        HStack(spacing: Spacing.medium) {
            StatusMark(isOK: check.isOK)
            VStack(alignment: .leading, spacing: 1) {
                Text(check.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(check.detail)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let title = check.buttonTitle {
                Button(title, action: action)
                    .secondaryButton()
                    .fixedSize()
                    .accessibilityIdentifier("overview.version.check.\(check.id).button")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview.version.check.\(check.id)")
    }
}

//
//  VersionCheckRow.swift
//  Atlas
//

import SwiftUI

/// One line of what goes to App Review: a mark, what it is, a detail, and
/// a button when something can be done about it.
struct VersionCheckRow: View {
    let check: ReleaseCheck
    let action: () -> Void

    var body: some View {
        HStack(spacing: Spacing.small) {
            StatusMark(isOK: check.isOK)
            VStack(alignment: .leading, spacing: 1) {
                Text(check.title)
                    .font(.callout)
                    .lineLimit(1)
                Text(check.detail)
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let title = check.buttonTitle {
                Button(title, action: action)
                    .buttonStyle(.link)
                    .controlSize(.small)
                    .accessibilityIdentifier("overview.version.check.\(check.id).button")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview.version.check.\(check.id)")
    }
}

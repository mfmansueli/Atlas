//
//  ImportProblemRow.swift
//  Atlas
//

import SwiftUI

/// A problem found in an imported file: yellow for what was skipped as
/// unknown, red for values that would break a limit.
struct ImportProblemRow: View {
    let problem: ListingImportProblem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: problem.isError ? "exclamationmark.circle" : "exclamationmark.triangle")
                .foregroundStyle(problem.isError ? Palette.err : Palette.warnMark)
                .accessibilityHidden(true)
            Text(problem.message)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(problem.isError ? Palette.errTint : Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("storePage.import.problem")
    }
}

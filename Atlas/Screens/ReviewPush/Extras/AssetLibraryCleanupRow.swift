//
//  AssetLibraryCleanupRow.swift
//  Atlas
//

import SwiftUI

/// Review & Push's line for an assistant's Asset Library cleanup: how many
/// unused files it suggests deleting and why, with Review Files… (the
/// Asset Library sheet, files picked) and Dismiss. Nothing is deleted
/// here, and a push doesn't delete them.
struct AssetLibraryCleanupRow: View {
    let suggestion: AssetLibraryCleanupSuggestion
    let appName: String
    let onReview: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "sparkle")
                .imageScale(.small)
                .foregroundStyle(Palette.ai)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                    if let confidence = suggestion.layers?.confidence { HowSureMeter(confidence: confidence) }
                }
                Text(suggestion.why)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(String(localized: "Dismiss", comment: "kind:button"), action: onDismiss)
                .accessibilityIdentifier("review.assetCleanup.dismiss")
            Button(String(localized: "Review Files…", comment: "kind:button"), action: onReview)
                .accessibilityIdentifier("review.assetCleanup.review")
        }
        .controlSize(.regular)
        .padding(Spacing.small)
        .background(Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier("review.assetCleanup")
    }

    /// "Claude Code suggests deleting 12 unused files from Lumen's Asset Library."
    private var title: String {
        let count = suggestion.fileIDs.count
        return count == 1
            ? String(localized: "\(suggestion.client) suggests deleting 1 unused file from \(appName)’s Asset Library.", comment: "kind:label")
            : String(localized: "\(suggestion.client) suggests deleting \(count) unused files from \(appName)’s Asset Library.", comment: "kind:label")
    }
}

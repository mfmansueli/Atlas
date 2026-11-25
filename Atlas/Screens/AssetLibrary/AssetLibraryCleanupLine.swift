//
//  AssetLibraryCleanupLine.swift
//  Atlas
//

import SwiftUI

/// An assistant's suggestion to delete unused files, at the top of the
/// Asset Library sheet: who suggests how many, why, Select Suggested and
/// Dismiss. Deleting stays the sheet's own Delete with its confirmation.
struct AssetLibraryCleanupLine: View {
    let title: String
    let suggestion: AssetLibraryCleanupSuggestion
    let onSelect: () -> Void
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
                    if let confidence = suggestion.layers?.confidence { HowSureMeter(confidence: confidence) }
                }
                Text(suggestion.why)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("assetLibrary.cleanup.why")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(String(localized: "Dismiss", comment: "kind:button"), action: onDismiss)
                .accessibilityIdentifier("assetLibrary.cleanup.dismiss")
            Button(String(localized: "Select Suggested", comment: "kind:button"), action: onSelect)
                .accessibilityIdentifier("assetLibrary.cleanup.select")
        }
        .controlSize(.regular)
        .padding(Spacing.small)
        .background(Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .aiArrived(key: suggestion.id.uuidString, arrivedAt: suggestion.receivedAt)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier("assetLibrary.cleanup")
    }
}

//
//  SettingsPaneHeader.swift
//  Atlas
//

import SwiftUI

/// A pane's title and the line under it, above its sections.
struct SettingsPaneHeader: View {
    let pane: SettingsPane

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(pane.title)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("settings.pane.title")
            Text(pane.subtitle)
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.pane.subtitle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets())
        .padding(.bottom, Spacing.xSmall)
    }
}

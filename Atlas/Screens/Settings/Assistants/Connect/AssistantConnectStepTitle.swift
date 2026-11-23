//
//  AssistantConnectStepTitle.swift
//  Atlas
//

import SwiftUI

/// A step's question or title in Connect's sheet, with the line under it.
struct AssistantConnectStepTitle: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.body.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("settings.connect.stepTitle")
            Text(detail)
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

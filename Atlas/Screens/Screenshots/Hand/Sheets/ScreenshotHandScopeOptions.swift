//
//  ScreenshotHandScopeOptions.swift
//  Atlas
//

import SwiftUI

/// "Replace it in": only the language in view, or every language with its
/// own screenshots.
struct ScreenshotHandScopeOptions: View {
    struct Option: Identifiable {
        let scope: ScreenshotHandScope
        let title: String
        let detail: String
        var isDisabled = false

        var id: ScreenshotHandScope { scope }
    }

    let label: String
    let options: [Option]
    @Binding var selection: ScreenshotHandScope

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(label)
                .font(.headline)
            ForEach(options) { option in
                RadioRow(title: option.title, detail: option.detail, isSelected: selection == option.scope, isDisabled: option.isDisabled) {
                    selection = option.scope
                }
                .accessibilityIdentifier("screenshots.hand.scope.\(option.scope == .one ? "one" : "every")")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

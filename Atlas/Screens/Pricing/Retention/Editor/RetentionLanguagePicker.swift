//
//  RetentionLanguagePicker.swift
//  Atlas
//

import SwiftUI

/// The language being edited: the one language picker (README-DS §12), in
/// its compact form, each language that runs too long saying so in the
/// menu (the banner under the fields says it for the one in view); and All
/// 18 languages for the table of every language.
struct RetentionLanguagePicker: View {
    let model: RetentionModel
    let message: RetentionMessage

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Language")
                .font(.callout)
                .foregroundStyle(Palette.label2)
            HStack(spacing: Spacing.small) {
                if let bar = LanguageBarModel.retention(languages: model.languages, selectedCode: model.selectedLocale, tooLong: tooLong) {
                    LanguagePickerButton(model: bar, style: .compact, identifier: "retention.languages") { locale in
                        model.selectedLocale = locale.code
                    }
                }
                Button(allLanguagesTitle) {
                    withAnimation(.snappy) { model.showsAllLanguages.toggle() }
                }
                .buttonStyle(.link)
                .font(.callout)
                .accessibilityIdentifier("retention.allLanguages")
            }
        }
    }

    private var tooLong: Set<String> {
        Set(model.languages.map(\.code).filter { message.text(for: $0).isTooLong })
    }

    private var allLanguagesTitle: String {
        model.showsAllLanguages ? String(localized: "Hide the list") : String(localized: "All \(model.languages.count) languages")
    }
}

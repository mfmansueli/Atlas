//
//  RetentionTooLongBanner.swift
//  Atlas
//

import SwiftUI

/// The selected language runs over 66 or 144: how far, and the assistant's
/// shorter version to take (with how sure it is and what it means), or a
/// button to ask for one.
struct RetentionTooLongBanner: View {
    let model: RetentionModel
    let message: RetentionMessage

    var body: some View {
        let text = model.selectedText
        if text.isTooLong, let locale = model.languages.first(where: { $0.code == model.selectedLocale }) {
            HStack(alignment: .center, spacing: Spacing.small) {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text(description(text, language: RetentionLanguages.shortName(of: locale, among: model.languages)))
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("retention.tooLong.text")
                    if let gloss = model.suggestion?.layers?.gloss { GlossLine(gloss: gloss) }
                }
                if let confidence = model.suggestion?.layers?.confidence { HowSureMeter(confidence: confidence) }
                if model.suggestion != nil {
                    Button("Use Shorter Version", action: model.useSuggestion)
                        .controlSize(.regular)
                        .accessibilityIdentifier("retention.tooLong.use")
                } else {
                    RetentionAskButton(
                        app: model.app,
                        kind: .shorten(
                            message: message.referenceName, language: locale.name, locale: locale.code, header: text.header, body: text.body
                        )
                    )
                    .controlSize(.regular)
                }
            }
            .padding(Spacing.medium)
            .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("retention.tooLong")
        }
    }

    /// "German: the message is 149 characters, and Apple allows 144.
    /// Claude Code suggests: “…”"
    private func description(_ text: RetentionText, language: String) -> String {
        var parts: [String] = []
        if text.isHeaderTooLong {
            parts.append(String(localized: "\(language): the header is \(text.headerCount) characters, and Apple allows \(RetentionLimits.headerLength)."))
        }
        if text.isBodyTooLong {
            parts.append(String(localized: "\(language): the message is \(text.bodyCount) characters, and Apple allows \(RetentionLimits.bodyLength)."))
        }
        if let suggestion = model.suggestion {
            parts.append(String(localized: "\(suggestion.client) suggests: “\(suggestion.body)”"))
        }
        return parts.joined(separator: " ")
    }
}

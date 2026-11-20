//
//  ProductPageRefusedTextCard.swift
//  Atlas
//

import SwiftUI

/// A promotional text an assistant sent that Atlas stopped: "Not
/// offered", with the words App Review would reject marked and why. It
/// can't be accepted; See the Rules and Ask for Another go on from here.
struct ProductPageRefusedTextCard: View {
    let app: StoreApp
    let suggestion: ProductPageTextSuggestion
    /// The page, or the suggested page, it was written for.
    let pageName: String
    /// What Ask for Another asks.
    let askPrompt: String

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                Pill(text: String(localized: "Not offered"), style: .warning)
                SuggestionSourceTag(source: .assistant(client: suggestion.source))
                Text("\(suggestion.source) suggested this text. Atlas’s check stopped it.")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(marked)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pages.refused.text")
            Text(suggestion.refusal)
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pages.refused.reason")
            HStack(spacing: Spacing.xSmall) {
                Spacer(minLength: 0)
                Button("See the Rules") {
                    HelpNavigation.shared.open(Self.rulesArticle)
                    openWindow(id: HelpCommands.windowID)
                }
                .accessibilityIdentifier("pages.refused.rules")
                ProductPagesAskButton(app: app, kind: .another(pageName: pageName), prompt: askPrompt, identifier: "pages.refused.ask")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.warningTint, in: shape)
        .overlay(shape.strokeBorder(Palette.warningMark.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.refused.\(suggestion.locale)")
    }

    /// The Help article with what promotional text can't say.
    static let rulesArticle = "pages"

    /// The text with the phrases App Review rejects marked.
    private var marked: AttributedString {
        var text = AttributedString(suggestion.text)
        for phrase in suggestion.refusedPhrases where !phrase.isEmpty {
            var searchStart = text.startIndex
            while let range = text[searchStart...].range(of: phrase, options: [.caseInsensitive]) {
                text[range].backgroundColor = Palette.dangerTint
                text[range].foregroundColor = Palette.danger
                text[range].underlineStyle = .single
                searchStart = range.upperBound
            }
        }
        return text
    }
}

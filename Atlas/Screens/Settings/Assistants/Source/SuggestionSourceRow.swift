//
//  SuggestionSourceRow.swift
//  Atlas
//

import SwiftUI

/// One choice of Settings → AI Assistants → "Where suggestions come from":
/// a radio button with the source and what it means, "Connected" when an
/// assistant is, and its own controls under it while it's chosen.
struct SuggestionSourceRow<Content: View>: View {
    let provider: TranslationProvider
    @Binding var selection: TranslationProvider
    var badge: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Button {
                selection = provider
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(isSelected ? Palette.accent : Palette.label2)
                        .imageScale(.large)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Spacing.xSmall) {
                            Text(provider.sourceTitle)
                                .font(.body.weight(.medium))
                            if let badge, isSelected {
                                Pill(text: badge)
                                    .accessibilityIdentifier("settings.source.badge")
                            }
                        }
                        Text(provider.sourceDetail)
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(provider.sourceTitle))
            .accessibilityHint(Text(provider.sourceDetail))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("settings.source.\(provider.rawValue)")
            if isSelected {
                content()
                    .padding(.leading, 28)
            }
        }
    }

    private var isSelected: Bool { selection == provider }
}

extension SuggestionSourceRow where Content == EmptyView {
    init(provider: TranslationProvider, selection: Binding<TranslationProvider>, badge: String? = nil) {
        self.init(provider: provider, selection: selection, badge: badge) { EmptyView() }
    }
}

//
//  ScreenshotsLanguageList.swift
//  Atlas
//

import SwiftUI

/// All Languages: every language with its own screenshots, with its state,
/// the captions suggested in it and a strip of its screenshots on the
/// device in view. Clicking one shows it.
struct ScreenshotsLanguageList: View {
    @Bindable var viewModel: ScreenshotsViewModel

    /// The region tile; the strip lines up with the name beside it.
    private static let tileWidth: CGFloat = 30

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.pageLocales.enumerated()), id: \.element) { index, locale in
                if index > 0 { Divider() }
                row(locale)
            }
        }
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.page.allLanguages")
    }

    private func row(_ locale: StoreLocale) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(locale)
            LanguageListThumbnails(viewModel: viewModel, locale: locale) { open(locale) }
                .padding(.leading, Spacing.medium + Self.tileWidth + Spacing.medium)
                .padding(.trailing, Spacing.medium)
                .padding(.bottom, Spacing.small)
        }
    }

    private func open(_ locale: StoreLocale) {
        viewModel.pageLocale = locale
        viewModel.pageShowsAll = false
    }

    private func header(_ locale: StoreLocale) -> some View {
        let count = viewModel.proposedCaptions(in: locale).count
        return Button {
            open(locale)
        } label: {
            HStack(spacing: Spacing.medium) {
                Text(locale.regionCode.uppercased())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                    .frame(width: Self.tileWidth, height: 22)
                    .background(Palette.fill2, in: RoundedRectangle(cornerRadius: Radius.flag, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(locale.name)
                    Text(viewModel.pageStatus(of: locale))
                        .font(.subheadline)
                        .foregroundStyle(count > 0 ? AnyShapeStyle(Palette.ai) : AnyShapeStyle(Palette.label2))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if count > 0 {
                    SuggestionBadge(count: count)
                } else if viewModel.pageStatus(of: locale) == String(localized: "Live") {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.increase)
                        .accessibilityHidden(true)
                }
                Image(systemName: "chevron.forward")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label3)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.allLanguagesAccessibilityLabel(of: locale)))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("screenshots.page.language.\(locale.code)")
    }
}

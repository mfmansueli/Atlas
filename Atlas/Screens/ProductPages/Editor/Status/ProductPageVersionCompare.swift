//
//  ProductPageVersionCompare.swift
//  Atlas
//

import SwiftUI

/// An approved page with a new version on the way: what's on the App
/// Store now beside what the new version has, in the editor's language,
/// with what changed marked.
struct ProductPageVersionCompare: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage
    let locale: String

    var body: some View {
        if let approved = page.approved {
            let next = page.nextVersion?.number ?? approved.number + 1
            HStack(alignment: .top, spacing: Spacing.medium) {
                column(
                    title: String(localized: "ON THE APP STORE NOW · VERSION \(approved.number), APPROVED"),
                    text: approved.localization(locale)?.promotionalText ?? "",
                    keywords: approved.localization(locale)?.keywords ?? [],
                    deepLink: approved.deepLink,
                    changed: []
                )
                Divider()
                column(
                    title: String(localized: "NEW · VERSION \(next), IN PREPARATION"),
                    text: viewModel.text(of: page, locale: locale),
                    keywords: viewModel.keywords(of: page, locale: locale),
                    deepLink: viewModel.deepLink(of: page),
                    changed: changed(from: approved)
                )
            }
            .padding(Spacing.medium)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("pages.compare")
        }
    }

    private enum Part { case text, keywords, deepLink }

    private func changed(from approved: ProductPageVersion) -> Set<Part> {
        var parts: Set<Part> = []
        if viewModel.text(of: page, locale: locale) != approved.localization(locale)?.promotionalText ?? "" { parts.insert(.text) }
        if Set(viewModel.keywords(of: page, locale: locale)) != Set(approved.localization(locale)?.keywords ?? []) { parts.insert(.keywords) }
        if viewModel.deepLink(of: page) != approved.deepLink { parts.insert(.deepLink) }
        return parts
    }

    private func column(title: String, text: String, keywords: [String], deepLink: String, changed: Set<Part>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.label2)
            value(
                String(localized: "Promotional text"),
                text.isEmpty ? String(localized: "Same as the default page") : text, isChanged: changed.contains(.text)
            )
            value(
                String(localized: "Keywords"),
                keywords.isEmpty ? String(localized: "None") : ProductPageChangeBuilder.keywordsText(keywords),
                isChanged: changed.contains(.keywords)
            )
            value(String(localized: "Deep link"), deepLink.isEmpty ? String(localized: "None") : deepLink, isChanged: changed.contains(.deepLink))
                .environment(\.layoutDirection, .leftToRight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func value(_ label: String, _ text: String, isChanged: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: Spacing.xxSmall) {
                Text(label).font(.subheadline).foregroundStyle(Palette.label2)
                if isChanged {
                    Pill(text: String(localized: "Changed"), style: .accent)
                        .fixedSize()
                }
            }
            Text(text)
                .font(.callout)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

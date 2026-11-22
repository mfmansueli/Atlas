//
//  ProductPageKeywordsBox.swift
//  Atlas
//

import SwiftUI

/// The page's search keywords in one language, chosen from the last
/// approved version's: a search for one shows this page once it's approved
/// and visible. A keyword leads to one page, so one another page has says
/// which. Before any version is approved there's nothing to choose from.
struct ProductPageKeywordsBox: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage
    let locale: String

    var body: some View {
        let available = viewModel.availableKeywords(locale)
        let chosen = viewModel.keywords(of: page, locale: locale)
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                if isPending { UnsavedDot(size: 6) }
                Text("Search Keywords")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if viewModel.defaultPage.hasApprovedVersion, !available.isEmpty {
                    Text("\(chosen.filter(available.contains).count) of \(available.count) chosen")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Palette.label2)
                        .accessibilityIdentifier("pages.keywords.count")
                }
            }
            Text("People who search these words in \(languageName) see this page, once it’s approved and visible.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            content(available: available, chosen: chosen)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.keywordsBox")
    }

    private var languageName: String { ProductPageChangeBuilder.localeName(locale) }

    private var isRightToLeft: Bool { StoreLocaleCatalog.locale(code: locale)?.isRTL ?? false }

    private var isPending: Bool {
        !page.isDraft && viewModel.edits(of: page).keywords[locale] != nil
    }

    @ViewBuilder
    private func content(available: [String], chosen: [String]) -> some View {
        if !viewModel.defaultPage.hasApprovedVersion {
            Banner(
                kind: .warning,
                title: String(localized: "Keywords can’t be chosen yet."),
                message: String(localized: """
                A page’s keywords come from the keywords of a version Apple has approved, and \(viewModel.app.name) has no \
                approved version. Everything else on the page can be prepared now; come back for keywords once a version is \
                approved.
                """),
                isInline: true
            )
            .accessibilityIdentifier("pages.keywords.noVersion")
        } else if available.isEmpty {
            Text("Version \(versionString)’s \(languageName) page has no keywords to choose from.")
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pages.keywords.none")
        } else if chosen.isEmpty, !viewModel.revealedKeywordLocales.contains(locale) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text("\(languageName) has no keywords chosen for this page, so searches in \(languageName) show the default page.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Choose Keywords…") { viewModel.revealedKeywordLocales.insert(locale) }
                    .controlSize(.small)
                    .disabled(!viewModel.canEdit(page))
                    .accessibilityIdentifier("pages.keywords.choose")
            }
            .accessibilityIdentifier("pages.keywords.empty")
        } else {
            FlowLayout(spacing: Spacing.xSmall, lineSpacing: Spacing.xSmall) {
                ForEach(available, id: \.self) { keyword in
                    ProductPageKeywordChip(
                        keyword: keyword,
                        isChosen: chosen.contains(keyword),
                        owner: chosen.contains(keyword) ? nil : viewModel.keywordOwner(keyword, locale: locale, except: page.id)?.name,
                        isEnabled: viewModel.canEdit(page)
                    ) {
                        viewModel.toggleKeyword(keyword)
                    }
                    .accessibilityIdentifier("pages.keyword.\(keyword)")
                }
            }
            .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
            Text("""
            Chosen from version \(versionString)’s \(languageName) keywords, the last version Apple approved. New words can’t be \
            typed here.
            """)
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var versionString: String {
        viewModel.defaultPage.approvedVersionString ?? ""
    }
}

//
//  ProductPagesEmptyView.swift
//  Atlas
//

import SwiftUI

/// No pages yet: what a custom product page is, what it can change, and
/// the two ways to start.
struct ProductPagesEmptyView: View {
    @Bindable var viewModel: ProductPagesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text("A page for each audience")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("A custom product page is another version of \(appName)’s App Store page with a link of its own. \(appName) has none yet.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: Spacing.medium) {
                point(
                    "link",
                    title: String(localized: "Send people to the right page."),
                    text: String(localized: "Use its link in an ad, a newsletter or on your website.")
                )
                point(
                    "magnifyingglass",
                    title: String(localized: "Show it for the searches you choose."),
                    text: String(localized: "Pick from the keywords of your approved version.")
                )
                point(
                    "photo.on.rectangle",
                    title: String(localized: "Change what they see first."),
                    text: String(localized: """
                    Screenshots, App Previews and promotional text, in each language. The name, icon and description stay the same.
                    """)
                )
            }
            Text("Up to 70 pages. Each one goes to App Review by itself, with no new version of the app.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.small) {
                Button("Create the First Page…") {
                    viewModel.isNewPagePresented = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canMakePages)
                .accessibilityIdentifier("pages.empty.new")
                ProductPagesAskButton(
                    app: viewModel.app, kind: .ideas, prompt: viewModel.suggestPagesPrompt, identifier: "pages.empty.ask"
                )
                .disabled(!viewModel.canMakePages)
            }
        }
        .padding(Spacing.xxLarge)
        .frame(maxWidth: 620, alignment: .leading)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.empty")
    }

    private var appName: String { viewModel.app.name }

    private func point(_ systemImage: String, title: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.sectionProductPages)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text("\(Text(title).fontWeight(.semibold)) \(Text(text).foregroundStyle(Palette.label2))")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

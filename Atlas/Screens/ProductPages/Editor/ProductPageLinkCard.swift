//
//  ProductPageLinkCard.swift
//  Atlas
//

import AppKit
import SwiftUI

/// The page's link (Copy, Open), whether it's visible on the App Store,
/// and its deep link with Atlas's check. Links read left to right in every
/// language.
struct ProductPageLinkCard: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            link
            Divider()
            visible
            Divider()
            deepLink
        }
        .padding(Spacing.medium)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.linkCard")
    }

    // MARK: - Link

    private var link: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            label("LINK")
            if let url = page.url {
                HStack(spacing: Spacing.small) {
                    Text(verbatim: url.absoluteString)
                        .font(.callout.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("pages.link.url")
                    Button("Copy") {
                        guard let url = viewModel.copyLink(of: page) else { return }
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    }
                    .accessibilityLabel(Text("Copy link"))
                    .accessibilityIdentifier("pages.link.copy")
                    Button("Open") { openURL(url) }
                        .accessibilityLabel(Text("Open the page on the App Store"))
                        .accessibilityIdentifier("pages.link.open")
                }
                .controlSize(.regular)
                .environment(\.layoutDirection, .leftToRight)
            } else {
                Text("Apple makes the link when the page is first pushed.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("pages.link.none")
            }
        }
    }

    // MARK: - Visible

    private var visible: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Visible on the App Store")
                    .font(.callout.weight(.medium))
                Text(visibleDetail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(
                "Visible on the App Store",
                isOn: Binding { viewModel.isVisible(page) } set: { viewModel.setVisible($0) }
            )
            .toggleStyle(.switch)
            .labelsHidden()
            .disabled(!canToggle)
            .accessibilityIdentifier("pages.visible")
        }
    }

    private var canToggle: Bool {
        page.state.isApproved && viewModel.canChange && !page.isDraft
    }

    private var visibleDetail: String {
        guard page.state.isApproved, !page.isDraft else {
            return String(localized: "Decided when you submit. A page can’t be visible before it’s approved.")
        }
        return viewModel.isVisible(page)
            ? String(localized: "People with the link, and searches for its keywords, see this page.")
            : String(localized: "The link opens the default page, and searches no longer lead here.")
    }

    // MARK: - Deep link

    private var deepLink: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            label("DEEP LINK")
            let check = viewModel.deepLinkCheck(for: page)
            TextField(
                "Deep link",
                text: Binding { viewModel.deepLink(of: page) } set: { viewModel.editDeepLink($0) },
                prompt: Text(verbatim: placeholder(check))
            )
            .textFieldStyle(.roundedBorder)
            .font(.callout.monospaced())
            .autocorrectionDisabled()
            .environment(\.layoutDirection, .leftToRight)
            .disabled(!viewModel.canEdit(page))
            .accessibilityIdentifier("pages.deepLink")
            checkLine(check.result)
                .accessibilityIdentifier("pages.deepLink.check")
        }
    }

    private func placeholder(_ check: ProductPageDeepLinkCheck) -> String {
        if let domain = check.domains.first { return "https://\(domain)/…" }
        if let scheme = check.schemes.first { return "\(scheme)://…" }
        return "https://…"
    }

    @ViewBuilder
    private func checkLine(_ result: ProductPageDeepLinkCheck.Result) -> some View {
        switch result {
        case .empty:
            Text("Optional. People who already have \(viewModel.app.name) tap Open and land on this part of the app.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        case let .fine(message):
            InlineMessage(text: message, systemImage: "checkmark.circle.fill", tint: Palette.decrease)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        case let .incomplete(message):
            InlineMessage(text: message, systemImage: "exclamationmark.octagon.fill", tint: Palette.err)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        case let .unfamiliar(message):
            InlineMessage.warning(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func label(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.label2)
    }
}

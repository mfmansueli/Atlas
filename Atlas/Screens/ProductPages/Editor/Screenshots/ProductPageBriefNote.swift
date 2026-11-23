//
//  ProductPageBriefNote.swift
//  Atlas
//

import SwiftUI

/// Under the screenshots of a page that still shows the default page's:
/// the brief its accepted suggestion left, who the page is for and the
/// screenshots it should lead with, which Make Screenshots for This Page
/// lays out from the default page's screens (board 52).
struct ProductPageBriefNote: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage
    let brief: ProductPageBrief
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Brief from \(brief.source)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.label2)
                .accessibilityAddTraits(.isHeader)
            if !brief.audience.isEmpty {
                Text(brief.audience)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pages.brief.audience")
            }
            Text("\(Text("Screenshots:").fontWeight(.semibold)) \(brief.screens)")
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("pages.brief.screens")
            Text(page.isDraft ? Self.draftText : Self.pushedText)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            if !page.isDraft {
                Button("Open in App Store Connect") { openURL(viewModel.appStoreConnectURL) }
                    .buttonStyle(.link)
                    .controlSize(.regular)
                    .accessibilityIdentifier("pages.brief.open")
            }
        }
        .padding(Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.brief")
    }

    static var draftText: String {
        String(localized: """
        Make Screenshots for This Page… lays these out from the default page’s screens. Until then the page shows the \
        default page’s, in search results too.
        """)
    }

    static var pushedText: String {
        String(localized: """
        Make Screenshots for This Page… lays these out from the default page’s screens, or add your own in App Store \
        Connect. Until then the page shows the default page’s, in search results too.
        """)
    }
}

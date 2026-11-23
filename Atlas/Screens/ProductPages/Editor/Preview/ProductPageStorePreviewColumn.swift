//
//  ProductPageStorePreviewColumn.swift
//  Atlas
//

import SwiftUI

/// One page as the App Store shows it: the app's icon and name, Get, the
/// first three screenshots and the promotional text.
struct ProductPageStorePreviewColumn: View {
    @Bindable var viewModel: ProductPagesViewModel
    let title: String
    let screenshots: LoadState<[LiveScreenshot]>
    let text: String
    let locale: String
    var outlinesScreenshots = false
    var outlinesText = false
    /// The page's own set waiting in Review & Push, shown in place of
    /// `screenshots` (board 52).
    var queued: [ProductPageScreenshotsPush.File]?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(title.uppercased())
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.label2)
            HStack(spacing: Spacing.xSmall) {
                AppIconTile(name: viewModel.app.name, icon: viewModel.app.icon, size: 28)
                Text(viewModel.app.name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Get")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.accentText)
                .padding(.horizontal, 10)
                .frame(height: 18)
                .background(Palette.fill2, in: Capsule())
                .accessibilityHidden(true)
            if let queued {
                PageShotsQueuedStrip(files: queued, device: viewModel.device, height: viewModel.device == .iPad ? 46 : 72, limit: 3)
            } else {
                ProductPageScreenshotStrip(
                    viewModel: viewModel, state: screenshots, device: viewModel.device,
                    height: viewModel.device == .iPad ? 46 : 72, isOwn: outlinesScreenshots, limit: 3
                )
            }
            Text(text)
                .font(.footnote)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                .frame(maxWidth: .infinity, alignment: isRightToLeft ? .trailing : .leading)
                .padding(Spacing.xxSmall)
                .overlay {
                    if outlinesText {
                        RoundedRectangle(cornerRadius: Radius.flag, style: .continuous).strokeBorder(Palette.accent, lineWidth: 1.5)
                    }
                }
        }
        .padding(Spacing.small)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Palette.content, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var isRightToLeft: Bool { StoreLocaleCatalog.locale(code: locale)?.isRTL ?? false }
}

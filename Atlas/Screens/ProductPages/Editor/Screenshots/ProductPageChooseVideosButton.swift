//
//  ProductPageChooseVideosButton.swift
//  Atlas
//

import SwiftUI

/// Choose App Previews…: videos the person already has become the page's
/// own App Previews in this language on the device shown, checked against
/// App Store Connect's size and length. Off while App Review has the page
/// or the key can't change pages.
struct ProductPageChooseVideosButton: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage
    let locale: String
    @State private var isReading = false

    var body: some View {
        Button {
            let language = ProductPageChangeBuilder.localeName(locale)
            guard let urls = ProductPageVideoFilePanel.choose(pageName: page.name, language: language, device: viewModel.device) else { return }
            isReading = true
            Task {
                await viewModel.chooseVideos(urls, for: page, locale: locale)
                isReading = false
            }
        } label: {
            if isReading {
                HStack(spacing: Spacing.xSmall) {
                    ProgressView().controlSize(.mini)
                    Text("Reading…")
                }
            } else {
                Text("Choose App Previews…")
            }
        }
        .controlSize(.small)
        .disabled(isReading || !viewModel.canChooseFiles(for: page))
        .help(Text("Use App Preview videos you already have for this page only. The default page doesn’t change."))
        .accessibilityIdentifier("pages.screenshots.chooseVideos")
    }
}

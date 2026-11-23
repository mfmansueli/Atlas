//
//  ProductPageChooseFilesButton.swift
//  Atlas
//

import SwiftUI

/// Choose Files…: screenshots the person already has become the page's own
/// in this language on the device shown, checked against the sizes App
/// Store Connect takes. Free, like editing a page. Off while App Review
/// has the page or the key can't change pages.
struct ProductPageChooseFilesButton: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage
    let locale: String

    var body: some View {
        Button("Choose Files…") {
            let language = ProductPageChangeBuilder.localeName(locale)
            guard let urls = ProductPageScreenshotFilePanel.choose(pageName: page.name, language: language, device: viewModel.device) else { return }
            viewModel.chooseFiles(urls, for: page, locale: locale)
        }
        .controlSize(.regular)
        .disabled(!viewModel.canChooseFiles(for: page))
        .help(Text("Use screenshots you already have for this page only. The default page doesn’t change."))
        .accessibilityIdentifier("pages.screenshots.chooseFiles")
    }
}

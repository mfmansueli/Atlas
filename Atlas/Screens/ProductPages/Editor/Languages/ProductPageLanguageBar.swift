//
//  ProductPageLanguageBar.swift
//  Atlas
//

import SwiftUI

/// The page's languages as the language bar (README-DS §12): the picker
/// with the language's suggested text, Accept All Languages for every
/// suggested text (Pro), the arrows and how many wait elsewhere; the menu
/// lists last the languages that show the default page's content.
struct ProductPageLanguageBar: View {
    @Bindable var viewModel: ProductPagesViewModel
    let page: ProductPage

    @Environment(ProGate.self) private var pro: ProGate?

    var body: some View {
        if let model = viewModel.languageBarModel(of: page) {
            LanguageBar(model: model, showsProChip: pro.isFree && model.withSuggestions.count > 1) { locale in
                viewModel.localeCode = locale.code
            } onAcceptAll: {
                let suggested = viewModel.acceptableTextSuggestions(of: page)
                pro.require(.acceptAllLanguages(suggestions: suggested.count, languages: suggested.count)) {
                    viewModel.acceptAllLanguages()
                }
            } onAcceptHere: {
                if let suggestion = viewModel.textSuggestion { viewModel.acceptText(suggestion) }
            } trailing: {
                EmptyView()
            }
        }
    }
}

//
//  ProductPagesScreen.swift
//  Atlas
//

import SwiftUI

/// Product Pages: the list of the app's pages, or the page being edited.
struct ProductPagesScreen: View {
    @Bindable var viewModel: ProductPagesViewModel

    var body: some View {
        List(viewModel.listedPages) { page in
            Text(page.name)
        }
    }
}

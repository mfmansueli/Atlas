//
//  ProductPagesScreen.swift
//  Atlas
//

import SwiftUI

/// Custom Product Pages: the list of the app's pages (board 50), or the
/// page being edited in its place (board 51). Under 900 points wide, the
/// list's rows take two lines and the editor leaves out its preview.
struct ProductPagesScreen: View {
    @Bindable var viewModel: ProductPagesViewModel
    /// Opens Review & Push: Push and Submit…, and the toast's button.
    let onReviewPush: () -> Void

    @State private var width: CGFloat = 1000

    static let compactWidth: CGFloat = 900

    var body: some View {
        Group {
            if let page = viewModel.selectedPage, viewModel.state.value != nil {
                ProductPageEditor(viewModel: viewModel, page: page, isCompact: isCompact, onReviewPush: onReviewPush)
            } else {
                ProductPagesListView(viewModel: viewModel, isCompact: isCompact)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.content)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private var isCompact: Bool { width < Self.compactWidth }
}

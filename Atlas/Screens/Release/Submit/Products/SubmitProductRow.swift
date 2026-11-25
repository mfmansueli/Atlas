//
//  SubmitProductRow.swift
//  Atlas
//

import SwiftUI

/// One subscription or in-app purchase Ready to Submit in the Submit
/// sheet, ticked to go to App Review with the version, as an In-App
/// Event's row is.
struct SubmitProductRow: View {
    @Bindable var viewModel: ReleaseViewModel
    let product: SubmissionProduct

    private var isTicked: Bool { viewModel.options.productIDs.contains(product.id) }

    var body: some View {
        Toggle(isOn: Binding { isTicked } set: { viewModel.setProduct(product.id, goesWithVersion: $0) }) {
            VStack(alignment: .leading, spacing: 1) {
                Text(product.title)
                    .font(.callout)
                Text(product.detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.checkbox)
        .accessibilityIdentifier("submit.product.\(product.id)")
    }
}

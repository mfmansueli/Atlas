//
//  StorePageTransferItems.swift
//  Atlas
//

import SwiftUI

/// What the Import & Export menu offers.
struct StorePageTransferItems: View {
    @Bindable var viewModel: StorePageViewModel

    var body: some View {
        Button("Import Translations…", systemImage: "square.and.arrow.down") {
            viewModel.isImporterPresented = true
        }
        Divider()
        Section("For translators") {
            ForEach(ListingTransferFormat.allCases) { format in
                Button(format.exportTitle, systemImage: "square.and.arrow.up") {
                    viewModel.exportFormat = format
                }
            }
        }
    }
}

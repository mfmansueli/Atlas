//
//  PricesByCountryDebugHost.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Prices by Country in a plain frame for its DEBUG scenes, with Lumen's
/// fixtures and Pricing's toast. `prepare` sets the scene up once the
/// product's prices are read.
struct PricesByCountryDebugHost: View {
    let productID: String
    var size = CGSize(width: 1000, height: 640)
    var filter: PricesByCountryFilter = .all
    var focusedTerritory: String?
    var prepare: @MainActor (PricingViewModel) async -> Void = { _ in }
    /// Runs once the table is on screen, e.g. to open a popover from a row.
    var present: @MainActor (PricingViewModel) -> Void = { _ in }

    @State private var viewModel = PricingViewModel(
        app: DebugFixtures.lumen,
        services: DebugPricingServices(),
        queue: ChangeQueue(),
        modes: PricingModeStore(defaults: nil, modes: [DebugFixtures.AppID.lumen: .showSuggestions]),
        commission: .smallBusiness
    )
    @State private var shownFilter: PricesByCountryFilter = .all
    @State private var shownFocus: String?
    @State private var isReady = false

    var body: some View {
        Group {
            if isReady {
                PricesByCountryView(viewModel: viewModel, productID: productID, filter: $shownFilter, focusedTerritory: $shownFocus)
            } else {
                PricesByCountrySkeleton()
            }
        }
        .padding(Spacing.xLarge)
        .frame(width: size.width, height: size.height)
        .background(Palette.content)
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toast {
                ActionToast(message: toast, duration: .seconds(3600)) {
                    viewModel.undoToast()
                } onAction: {
                    viewModel.toast = nil
                } onDismiss: {
                    if viewModel.toast == toast { viewModel.toast = nil }
                }
                .padding(.bottom, Spacing.large)
            }
        }
        .task {
            shownFilter = filter
            await viewModel.load()
            await viewModel.productsTask?.value
            viewModel.pricesByCountry.show(productID: productID)
            await prepare(viewModel)
            shownFocus = focusedTerritory
            isReady = true
            try? await Task.sleep(for: .milliseconds(600))
            present(viewModel)
        }
    }
}
#endif

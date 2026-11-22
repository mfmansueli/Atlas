//
//  AppPriceAvailabilityCards.swift
//  Atlas
//

import SwiftUI

/// App Store Connect's Pricing and Availability, on Pricing's Prices page:
/// the App Price and Availability cards side by side (one above the other
/// when narrow), with their sheets.
struct AppPriceAvailabilityCards: View {
    @Bindable var model: AppPriceAvailabilityModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            // Side by side, both as tall as the taller one, their links
            // on the same line at the bottom.
            HStack(alignment: .top, spacing: Spacing.medium) {
                AppPriceCard(model: model)
                    .frame(minWidth: 280, maxHeight: .infinity)
                AppAvailabilityCard(model: model)
                    .frame(minWidth: 280, maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Spacing.medium) {
                AppPriceCard(model: model)
                AppAvailabilityCard(model: model)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.appSale")
        .sheet(isPresented: $model.isPriceSheetPresented) {
            AppPriceSheet(model: model)
        }
        .sheet(isPresented: $model.isAvailabilitySheetPresented) {
            if let availability = model.availability.value?.availability {
                AppAvailabilityEditSheet(model: model, availability: availability)
            } else {
                AppAvailabilitySetupSheet(model: model)
            }
        }
    }
}

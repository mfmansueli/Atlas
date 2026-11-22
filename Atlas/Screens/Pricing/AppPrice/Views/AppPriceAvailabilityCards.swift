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
            HStack(alignment: .top, spacing: Spacing.medium) {
                AppPriceCard(model: model)
                    .frame(minWidth: 280)
                AppAvailabilityCard(model: model)
                    .frame(minWidth: 280)
            }
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

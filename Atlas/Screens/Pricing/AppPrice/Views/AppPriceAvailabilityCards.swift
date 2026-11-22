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
            EqualHeightRow(spacing: Spacing.medium, minColumnWidth: 280) {
                AppPriceCard(model: model, fillsHeight: true)
                AppAvailabilityCard(model: model, fillsHeight: true)
            }
            VStack(alignment: .leading, spacing: Spacing.medium) {
                AppPriceCard(model: model)
                AppAvailabilityCard(model: model)
            }
        }
        // Never measured narrower than one card: at a width near zero their
        // wrapping texts asked for thousands of points of height, the page's
        // minimum grew past the window, and the window's whole content was
        // centered and cut off at the top (sidebar included).
        .frame(minWidth: 280)
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

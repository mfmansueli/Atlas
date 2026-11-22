//
//  AppAvailabilityEditSheet.swift
//  Atlas
//

import SwiftUI

/// Edit Countries and Regions…: every country or region of the app's
/// availability with a checkbox, starting from what Review & Push already
/// holds. Add to Review & Push queues one change per country or region
/// that differs from App Store Connect.
struct AppAvailabilityEditSheet: View {
    @Bindable var model: AppPriceAvailabilityModel
    let availability: AppAvailability

    @State private var selection: Set<String>

    init(model: AppPriceAvailabilityModel, availability: AppAvailability) {
        self.model = model
        self.availability = availability
        _selection = State(initialValue: Set(availability.territories.filter(model.isAvailable).map(\.territoryID)))
    }

    private var territories: [AppTerritory] {
        availability.territories.map { AppTerritory(id: $0.territoryID) }
    }

    /// Countries and regions that differ from App Store Connect.
    private var changeCount: Int {
        availability.territories.count { selection.contains($0.territoryID) != $0.isAvailable }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text("Countries and Regions")
                        .font(.title2.weight(.semibold))
                    Text("Where \(model.app.name) is sold. Each country or region you turn on or off waits in Review & Push.")
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                AppTerritoryChecklist(territories: territories, selection: $selection)
                if availability.availableInNewTerritories != nil {
                    Text("Whether new countries and regions get it is set in App Store Connect: Apple’s API can’t change it.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Spacing.xLarge)
            Divider()
            HStack {
                Text(changeCount == 0 ? String(localized: "No changes") : String(localized: "\(changeCount) changes"))
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("pricing.availabilityEdit.count")
                Spacer()
                Button("Cancel") { model.isAvailabilitySheetPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("pricing.availabilityEdit.cancel")
                Button("Add to Review & Push") {
                    let wanted = Dictionary(uniqueKeysWithValues: availability.territories.map { ($0.territoryID, selection.contains($0.territoryID)) })
                    model.queueTerritories(wanted)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("pricing.availabilityEdit.add")
            }
            .buttonBorderShape(.capsule)
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.medium)
        }
        .frame(width: 480)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.availabilityEditSheet")
    }
}

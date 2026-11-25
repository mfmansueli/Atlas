//
//  PriceTestEndSheet.swift
//  Atlas
//

import SwiftUI

/// Ending a running test (board 76): End Test Early… (`pt-stop`) or a
/// new price in one of its countries (`pt-conflict`). Ending before day
/// 28 gives no result; the old prices wait in Review & Push.
struct PriceTestEndSheet: View {
    let test: PriceTest
    let ending: PriceTestEnding
    let today: Date
    let onCancel: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text(title)
                .atlasTextStyle(.title2)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(what)
                    .atlasTextStyle(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text(consequence)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Spacing.small) {
                Spacer()
                Button(String(localized: "Cancel", comment: "kind:button"), action: onCancel)
                    .secondaryButton()
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("priceTest.end.cancel")
                Button(buttonTitle, action: onEnd)
                    .primaryButton(isDefault: true)
                    .accessibilityIdentifier("priceTest.end.confirm")
            }
        }
        .padding(Spacing.xxLarge)
        .frame(width: Metrics.priceTestSmallSheetWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("priceTest.end")
    }

    private var title: String {
        ending.setsPrice
            ? String(localized: "End the \(test.region.title) Price Test?", comment: "kind:sheet-title")
            : String(localized: "End the \(test.region.title) Price Test Early?", comment: "kind:sheet-title")
    }

    private var what: String {
        guard let territoryID = ending.territoryID, let price = ending.price, let country = test.country(territoryID) else {
            return String(localized: "The old prices come back in \(test.countries.count) countries when you push.", comment: "kind:sheet-body")
        }
        let name = TerritoryCatalog.standard.territory(alpha3: territoryID)?.name ?? territoryID
        let others = test.countries.count - 1
        return String(
            localized: "\(name) at \(country.currency.format(price)) ends the test. The other \(others) go back to their old prices.",
            comment: "kind:sheet-body"
        )
    }

    private var consequence: String {
        let day = test.day(on: today)
        let line = String(localized: "With \(day) of \(PriceTest.days) days, there’s no result. Everything waits in Review & Push.", comment: "kind:sheet-body")
        guard test.countries.contains(where: { !$0.isRaise }) else { return line }
        return line + " " + String(localized: "People who paid the test price keep it.", comment: "kind:sheet-body")
    }

    private var buttonTitle: String {
        ending.setsPrice
            ? String(localized: "End Test and Set Price", comment: "kind:button")
            : String(localized: "End Test", comment: "kind:button")
    }
}

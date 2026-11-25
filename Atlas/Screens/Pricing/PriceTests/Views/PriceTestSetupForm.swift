//
//  PriceTestSetupForm.swift
//  Atlas
//

import SwiftUI

/// Test a Price (board 76, `pt-setup*`): the region with its 28 days,
/// the test price, the sample first (Continue waits for 30 starts and 100
/// page views), what it's compared with, the 28 days, and what existing
/// subscribers pay. Continue opens the confirmation.
struct PriceTestSetupForm: View {
    let viewModel: PricingViewModel
    @Binding var setup: PriceTestSetup

    var body: some View {
        let planner = viewModel.priceTestPlanner(productID: setup.productID)
        let plan = planner?.plan(setup)
        VStack(alignment: .leading, spacing: Spacing.large) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("Test a Price", comment: "kind:sheet-title")
                    .atlasTextStyle(.title2)
                Text("\(productName). One region pays a different price for 28 days; Results says what it did.", comment: "kind:sheet-body")
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            regions(planner?.options() ?? [])
            price(plan)
            if let plan {
                comparison(plan, planner: planner)
                length
                subscribers(plan)
            }
            buttons(plan)
        }
        .padding(Spacing.xxLarge)
        .frame(width: Metrics.priceTestSheetWidth)
        .task(id: setup.region) {
            guard let region = setup.region else { return }
            await viewModel.loadPriceTestPoints(productID: setup.productID, region: region)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("priceTest.setup")
    }

    private var productName: String {
        viewModel.countriesProduct(productID: setup.productID)?.name ?? ""
    }

    // MARK: - Region

    private func regions(_ options: [PriceTestRegionOption]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("Region", comment: "kind:field-label")
                .atlasTextStyle(.headline)
            ForEach(options) { option in
                PriceTestRegionRow(option: option, isSelected: setup.region == option.region) {
                    setup.region = option.region
                    setup.control = .automatic
                }
            }
            Text("The \(viewModel.countriesBaseName(productID: setup.productID)) price stays: it’s the base price.", comment: "kind:sheet-body")
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
        }
    }

    // MARK: - Price

    private func price(_ plan: PriceTestPlan?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Test price", comment: "kind:field-label")
                .atlasTextStyle(.headline)
            Picker(String(localized: "Test price", comment: "kind:field-label"), selection: $setup.step) {
                ForEach(PriceTestStep.choices, id: \.self) { step in
                    Text(step.title).tag(step)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("priceTest.step")
            if let plan, !plan.examples.isEmpty {
                Text("\(PriceTestText.examples(plan.examples)). Rounded to Apple’s price points.", comment: "kind:sheet-body")
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("priceTest.examples")
            }
            if let plan { sample(plan) }
        }
    }

    /// The sample first: what the 28 days can tell, or why it can't.
    @ViewBuilder
    private func sample(_ plan: PriceTestPlan) -> some View {
        if let refusal = plan.refusal {
            InlineMessage.warning(refusal)
                .accessibilityIdentifier("priceTest.refusal")
        } else {
            Text(sampleLine(plan))
                .atlasTextStyle(.callout)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("priceTest.sample")
        }
    }

    /// "Last 28 days: 2,140 page views, 96 starts (4.5%). Enough to tell a
    /// change of about 2.2 points."
    private func sampleLine(_ plan: PriceTestPlan) -> String {
        let views = PricingText.grouped(plan.sample.pageViews)
        let starts = PricingText.grouped(plan.sample.starts)
        let rate = plan.sample.conversion.map { PricingText.percent($0, places: 1) } ?? "—"
        let line = String(localized: "Last 28 days: \(views) page views, \(starts) starts (\(rate)).", comment: "kind:sheet-body")
        guard let points = plan.detectablePoints else { return line }
        let size = String(format: "%.1f", points)
        return line + " " + String(localized: "Enough to tell a change of about \(size) points.", comment: "kind:sheet-body")
    }

    // MARK: - Comparison

    private func comparison(_ plan: PriceTestPlan, planner: PriceTestPlanner?) -> some View {
        let samples = planner?.samples ?? [:]
        let underTest = PriceTestRules.regionsUnderTest(viewModel.priceTests.tests, on: viewModel.today())
        let automatic = planner?.control(for: plan.region, choice: .automatic)
        return VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Compared with", comment: "kind:field-label")
                .atlasTextStyle(.headline)
            Picker(String(localized: "Compared with", comment: "kind:field-label"), selection: $setup.control) {
                Text(automaticTitle(automatic)).tag(PriceTestControlChoice.automatic)
                Divider()
                ForEach(TerritoryRegion.allCases.filter { $0 != plan.region }, id: \.self) { region in
                    Text(region.title)
                        .tag(PriceTestControlChoice.region(region))
                        .selectionDisabled(!PriceTestRules.canCompare(region, with: plan.region, sample: samples[region], underTest: underTest))
                }
                Divider()
                Text("No Comparison", comment: "kind:menu-item").tag(PriceTestControlChoice.none)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("priceTest.control")
            if plan.control == nil {
                InlineMessage.warning(String(
                    localized: "Without a comparison, seasons and featuring can look like the price. The result is less sure.",
                    comment: "kind:inline-warning"
                ))
                .accessibilityIdentifier("priceTest.noComparison")
            } else {
                Text("Same 28 days at its usual price. It takes seasons and featuring out of the result.", comment: "kind:sheet-body")
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func automaticTitle(_ region: TerritoryRegion?) -> String {
        guard let region else { return String(localized: "Automatic: none with 30 starts", comment: "kind:menu-item") }
        return String(localized: "Automatic: \(region.title)", comment: "kind:menu-item")
    }

    // MARK: - Length and subscribers

    private var length: some View {
        let ends = Calendar.gmtGregorian.date(byAdding: .day, value: PriceTest.days, to: viewModel.today()) ?? viewModel.today()
        return VStack(alignment: .leading, spacing: Spacing.tiny) {
            Text("Length", comment: "kind:field-label")
                .atlasTextStyle(.headline)
            Text("28 days · ends about \(PricingText.date(ends))", comment: "kind:sheet-body")
                .atlasTextStyle(.callout)
            Text("The same 28 days Results compares. Then the old prices come back on their own.", comment: "kind:sheet-body")
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func subscribers(_ plan: PriceTestPlan) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Existing subscribers", comment: "kind:field-label")
                .atlasTextStyle(.headline)
            if plan.hasRaises {
                Text("Existing subscribers keep their price. Only new subscribers pay the test price.", comment: "kind:sheet-body")
                    .atlasTextStyle(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if plan.hasDecreases {
                Text("Subscribers there who renew during the test pay the lower price.", comment: "kind:sheet-body")
                    .atlasTextStyle(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle(String(localized: "People who pay the test price keep it afterward", comment: "kind:sheet-body"), isOn: $setup.keepsTestPrice)
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("priceTest.keep")
                if !setup.keepsTestPrice {
                    InlineMessage.warning(String(
                        localized: """
                        Then the old price is an increase for them. Apple tells them, and in some countries they must agree \
                        or the subscription ends.
                        """,
                        comment: "kind:inline-warning"
                    ))
                    .accessibilityIdentifier("priceTest.consent")
                }
            }
        }
    }

    // MARK: - Buttons

    private func buttons(_ plan: PriceTestPlan?) -> some View {
        HStack(spacing: Spacing.small) {
            Spacer()
            Button(String(localized: "Cancel", comment: "kind:button")) { viewModel.priceTests.setup = nil }
                .secondaryButton()
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("priceTest.cancel")
            Button(String(localized: "Continue", comment: "kind:button")) { setup.isConfirming = true }
                .primaryButton(isDefault: true)
                .disabled(plan?.canContinue != true)
                .accessibilityIdentifier("priceTest.continue")
        }
    }
}

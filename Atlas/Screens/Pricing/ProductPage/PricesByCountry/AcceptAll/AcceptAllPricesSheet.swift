//
//  AcceptAllPricesSheet.swift
//  Atlas
//

import SwiftUI

/// Accept All N… (board 73, `pr-prod-acc`, risk level 3): how many
/// countries go down and up with three examples each, when the changes
/// start (right away or a date, the price's `startDate`), and for
/// increases whether existing subscribers keep their price
/// (`preserveCurrentPrice`). Add to Review & Push queues them; nothing
/// reaches the App Store until you push, and Review & Push can undo it.
struct AcceptAllPricesSheet: View {
    let plan: AcceptAllPricesPlan
    let productName: String
    /// A subscription; an in-app purchase's prices change on push, and keep
    /// no current price.
    let canSchedule: Bool
    let onCancel: () -> Void
    let onAdd: (PriceSchedule) -> Void

    @State private var startsOnDate: Bool
    @State private var day: Date
    @State private var preservesCurrentPrice: Bool
    private let earliestDay: Date

    init(
        plan: AcceptAllPricesPlan,
        productName: String,
        canSchedule: Bool,
        schedule: PriceSchedule,
        today: Date = .now,
        calendar: Calendar = .current,
        onCancel: @escaping () -> Void,
        onAdd: @escaping (PriceSchedule) -> Void
    ) {
        self.plan = plan
        self.productName = productName
        self.canSchedule = canSchedule
        self.onCancel = onCancel
        self.onAdd = onAdd
        let earliest = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today)) ?? today
        earliestDay = earliest
        _startsOnDate = State(initialValue: schedule.isScheduled)
        _day = State(initialValue: schedule.startDay.flatMap { PriceSchedule.date(ofDay: $0, in: calendar) } ?? earliest)
        _preservesCurrentPrice = State(initialValue: schedule.preservesCurrentPrice)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("Accept \(plan.count) Suggested Prices?", comment: "kind:sheet-title")
                    .atlasTextStyle(.title2)
                Text(productName)
                    .atlasTextStyle(.callout)
                    .foregroundStyle(Palette.label2)
            }
            HStack(alignment: .top, spacing: Spacing.large) {
                if plan.downCount > 0 { group(plan.downTitle, plan.downExamples) }
                if plan.upCount > 0 { group(plan.upTitle, plan.upExamples) }
            }
            if canSchedule {
                start
                if plan.hasIncreases { keepPrice }
            }
            Text("They wait in Review & Push. Nothing changes on the App Store until you push, and you can undo them there.", comment: "kind:sheet-body")
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.small) {
                Spacer()
                Button(String(localized: "Cancel", comment: "kind:button"), action: onCancel)
                    .secondaryButton()
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("countries.acceptAll.cancel")
                Button(String(localized: "Add to Review & Push", comment: "kind:button")) { onAdd(schedule) }
                    .primaryButton(isDefault: true)
                    .accessibilityIdentifier("countries.acceptAll.add")
            }
        }
        .padding(Spacing.xxLarge)
        .frame(width: Metrics.countriesAcceptAllWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("countries.acceptAll")
    }

    private var schedule: PriceSchedule {
        PriceSchedule(
            startDay: canSchedule && startsOnDate ? PriceSchedule.day(of: day) : nil,
            preservesCurrentPrice: canSchedule ? preservesCurrentPrice : true
        )
    }

    private func group(_ title: String, _ examples: [AcceptAllPricesPlan.Example]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(title)
                .atlasTextStyle(.headline)
                .monospacedDigit()
            ForEach(examples) { example in
                HStack(spacing: Spacing.xSmall) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(example.name)
                            .atlasTextStyle(.callout)
                            .lineLimit(1)
                        Text(example.prices)
                            .atlasTextStyle(.subheadline)
                            .foregroundStyle(Palette.label2)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    Spacer(minLength: Spacing.xxSmall)
                    PriceChangePill(change: example.change)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("Price changes start", comment: "kind:field-label")
                .atlasTextStyle(.headline)
            RadioRow(title: String(localized: "Right away", comment: "kind:sheet-body"), isSelected: !startsOnDate) { startsOnDate = false }
                .accessibilityIdentifier("countries.acceptAll.now")
            HStack {
                RadioRow(title: String(localized: "On a date", comment: "kind:label"), isSelected: startsOnDate) { startsOnDate = true }
                    .accessibilityIdentifier("countries.acceptAll.onDate")
                DatePicker(String(localized: "Start date", comment: "kind:label"), selection: $day, in: earliestDay..., displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.stepperField)
                    .disabled(!startsOnDate)
                    .fixedSize()
                    .accessibilityIdentifier("countries.acceptAll.date")
            }
        }
    }

    private var keepPrice: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Toggle(String(localized: "Keep their current price where it goes up", comment: "kind:sheet-body"), isOn: $preservesCurrentPrice)
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("countries.acceptAll.keep")
            Text("Existing subscribers keep what they pay; new ones get the higher price.", comment: "kind:sheet-body")
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            if !preservesCurrentPrice {
                Label {
                    Text("Some countries ask subscribers to agree to an increase, or the subscription ends at renewal.", comment: "kind:sheet-body")
                        .atlasTextStyle(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.warnMark)
                }
                .padding(Spacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.warnTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
                .accessibilityIdentifier("countries.acceptAll.consent")
            }
        }
    }
}

//
//  IntroductoryOfferSheet.swift
//  Atlas
//

import SwiftUI

/// Add Introductory Offer… for one subscription, App Store Connect's or a
/// new one waiting in Review & Push: a free trial, pay as you go or pay up
/// front with its US price (equalized everywhere else), where it runs, and
/// when. Add to Review & Push queues it; the push creates it in every
/// country or region it runs in.
struct IntroductoryOfferSheet: View {
    let target: PurchaseSetupTarget
    let problems: (NewIntroductoryOffer) -> [IntroductoryOfferProblem]
    let onCancel: () -> Void
    let onAdd: (NewIntroductoryOffer) -> Void

    @State private var offer = NewIntroductoryOffer(mode: .freeTrial, duration: .oneWeek)
    @State private var priceText = ""
    @State private var choosesTerritories = false
    @State private var chosen: Set<String> = [NewSubscription.baseTerritoryID]
    @State private var hasStart = false
    @State private var hasEnd = false
    @State private var start = Date.now
    @State private var end = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var showsProblems = false

    private var period: SubscriptionPeriod { target.period ?? .oneMonth }

    /// The form as an offer.
    private var current: NewIntroductoryOffer {
        var offer = offer
        offer.price = offer.mode == .freeTrial ? nil : NewSubscription.price(from: priceText)
        offer.territories = choosesTerritories ? .chosen(chosen.sorted()) : .everywhere
        offer.startDate = hasStart ? start : nil
        offer.endDate = hasEnd ? end : nil
        return offer
    }

    private var currentProblems: [IntroductoryOfferProblem] {
        problems(current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Form {
                termsSection
                if offer.mode != .freeTrial { priceSection }
                territorySection
                datesSection
                if showsProblems, !currentProblems.isEmpty { problemSection }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            Divider()
            footer
        }
        .frame(width: 520)
        .frame(minHeight: 420, idealHeight: 600, maxHeight: 680)
        .onChange(of: offer.mode) { fitDuration() }
        .onAppear { fitDuration() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.introductoryOffer")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("Introductory offer")
                .font(.title2.weight(.semibold))
            Text("For new subscribers of \(target.name). It waits in Review & Push; nothing changes in App Store Connect until you push.")
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.xLarge)
    }

    private var termsSection: some View {
        Section {
            Picker("Type", selection: $offer.mode) {
                ForEach(OfferPaymentMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .accessibilityIdentifier("pricing.introductoryOffer.mode")
            Picker(offer.mode == .payAsYouGo ? "Each period" : "Duration", selection: $offer.duration) {
                ForEach(offer.mode.allowedDurations(for: period), id: \.self) { duration in
                    Text(duration.title).tag(duration)
                }
            }
            .accessibilityIdentifier("pricing.introductoryOffer.duration")
            if offer.mode == .payAsYouGo {
                let range = offer.mode.allowedPeriods(for: period)
                Stepper(value: $offer.numberOfPeriods, in: range) {
                    Text("For \(offer.numberOfPeriods) periods")
                }
                .accessibilityIdentifier("pricing.introductoryOffer.periods")
            }
        } header: {
            Text("Offer")
        } footer: {
            note(current.summary)
        }
    }

    private var priceSection: some View {
        Section {
            LabeledContent {
                HStack(spacing: Spacing.xSmall) {
                    TextField("Price", text: $priceText, prompt: Text(verbatim: "0.99"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)
                        .accessibilityIdentifier("pricing.introductoryOffer.price")
                    Text(verbatim: "USD")
                        .foregroundStyle(Palette.label2)
                }
            } label: {
                Text(offer.mode == .payAsYouGo ? "Price each period in the United States" : "Price in the United States")
            }
        } header: {
            Text("Price")
        } footer: {
            note(String(localized: "Every other country or region gets the price Apple equalizes with it."))
        }
    }

    private var territorySection: some View {
        Section {
            Picker("Where", selection: $choosesTerritories) {
                Text("Everywhere it’s sold").tag(false)
                Text("Chosen countries or regions").tag(true)
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("pricing.introductoryOffer.where")
            if choosesTerritories {
                IntroductoryOfferTerritoryList(chosen: $chosen)
                    .frame(height: 180)
            }
        } header: {
            Text("Countries or regions")
        }
    }

    private var datesSection: some View {
        Section {
            Toggle("Starts on a date", isOn: $hasStart)
                .accessibilityIdentifier("pricing.introductoryOffer.hasStart")
            if hasStart {
                DatePicker("Starts", selection: $start, displayedComponents: .date)
            }
            Toggle("Ends on a date", isOn: $hasEnd)
                .accessibilityIdentifier("pricing.introductoryOffer.hasEnd")
            if hasEnd {
                DatePicker("Ends", selection: $end, displayedComponents: .date)
            }
        } header: {
            Text("When")
        } footer: {
            note(String(localized: "Without dates it starts once it’s pushed and runs until you end it."))
        }
    }

    private var problemSection: some View {
        Section {
            ForEach(currentProblems, id: \.self) { problem in
                Text(problem.message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.err)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("pricing.introductoryOffer.problems")
    }

    private var footer: some View {
        HStack(spacing: Spacing.small) {
            Text("Customers get one introductory offer per subscription group.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("pricing.introductoryOffer.cancel")
            Button("Add to Review & Push", action: add)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("pricing.introductoryOffer.add")
        }
        .buttonBorderShape(.capsule)
        .padding(.horizontal, Spacing.xLarge)
        .padding(.vertical, Spacing.medium)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A duration the mode allows, and periods in its range.
    private func fitDuration() {
        let durations = offer.mode.allowedDurations(for: period)
        if !durations.contains(offer.duration), let first = durations.first { offer.duration = first }
        let range = offer.mode.allowedPeriods(for: period)
        offer.numberOfPeriods = min(max(offer.numberOfPeriods, range.lowerBound), range.upperBound)
    }

    private func add() {
        guard currentProblems.isEmpty else {
            showsProblems = true
            return
        }
        onAdd(current)
    }
}

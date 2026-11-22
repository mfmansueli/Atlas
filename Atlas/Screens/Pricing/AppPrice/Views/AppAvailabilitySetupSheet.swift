//
//  AppAvailabilitySetupSheet.swift
//  Atlas
//

import SwiftUI

/// Set Up Availability…: every country or region App Store Connect has
/// (the default) or the ones chosen, whether new ones get the app, and an
/// optional pre-order until its release date. Add to Review & Push queues
/// the app's first availability.
struct AppAvailabilitySetupSheet: View {
    @Bindable var model: AppPriceAvailabilityModel

    @State private var isEverywhere: Bool
    @State private var selection: Set<String>
    @State private var availableInNewTerritories: Bool
    @State private var offersPreOrder: Bool
    @State private var releaseDate: Date

    init(model: AppPriceAvailabilityModel) {
        self.model = model
        let queued = model.queuedSetupValue
        _isEverywhere = State(initialValue: queued?.isEverywhere ?? true)
        _selection = State(initialValue: queued?.availableTerritoryIDs ?? [])
        _availableInNewTerritories = State(initialValue: queued?.availableInNewTerritories ?? true)
        _offersPreOrder = State(initialValue: queued?.preOrderReleaseDate != nil)
        let today = model.today()
        let queuedDate = queued?.preOrderReleaseDate.flatMap { AppAvailabilityRules.date(from: $0) }
        _releaseDate = State(initialValue: queuedDate ?? AppAvailabilityRules.suggestedReleaseDate(today: today))
    }

    private var territories: [AppTerritory] {
        model.territories.value ?? []
    }

    private var setup: AppAvailabilitySetup {
        let ids = territories.map(\.id)
        return AppAvailabilitySetup(
            allTerritoryIDs: ids,
            availableTerritoryIDs: isEverywhere ? Set(ids) : selection,
            availableInNewTerritories: availableInNewTerritories,
            preOrderReleaseDate: offersPreOrder ? AppAvailabilityRules.day(releaseDate) : nil
        )
    }

    private var problems: [AppAvailabilityProblem] {
        model.problems(for: setup)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                header
                switch model.territories {
                case .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                case let .failed(message):
                    InlineMessage.error(message)
                    Button("Try Again") { Task { await model.loadTerritories() } }
                case .loaded:
                    form
                }
            }
            .padding(Spacing.xLarge)
            Divider()
            footer
        }
        .frame(width: 520)
        .task { await model.loadTerritories() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.availabilitySetupSheet")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("Set Up Availability")
                .font(.title2.weight(.semibold))
            Text("""
            Where \(model.app.name) will be sold. App Store Connect can’t remove an availability once it’s set up; you \
            can turn countries and regions on and off here afterwards.
            """)
            .font(.callout)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var form: some View {
        VStack(alignment: .leading, spacing: 2) {
            RadioRow(
                title: String(localized: "Every country or region"),
                detail: String(localized: "\(territories.count) countries and regions"),
                isSelected: isEverywhere
            ) {
                isEverywhere = true
            }
            .accessibilityIdentifier("pricing.availabilitySetup.everywhere")
            RadioRow(title: String(localized: "Choose countries and regions"), isSelected: !isEverywhere) {
                if isEverywhere, selection.isEmpty { selection = Set(territories.map(\.id)) }
                isEverywhere = false
            }
            .accessibilityIdentifier("pricing.availabilitySetup.choose")
        }
        if !isEverywhere {
            AppTerritoryChecklist(territories: territories, selection: $selection)
        }
        Toggle("Make it available in new countries and regions automatically", isOn: $availableInNewTerritories)
            .accessibilityIdentifier("pricing.availabilitySetup.newTerritories")
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Toggle("Offer for pre-order", isOn: $offersPreOrder)
                .accessibilityIdentifier("pricing.availabilitySetup.preOrder")
            if offersPreOrder {
                DatePicker(
                    "Release date",
                    selection: $releaseDate,
                    in: AppAvailabilityRules.earliestReleaseDate(today: model.today())...AppAvailabilityRules.latestReleaseDate(today: model.today()),
                    displayedComponents: .date
                )
                .accessibilityIdentifier("pricing.availabilitySetup.releaseDate")
                Text("""
                People can order it now and download it on its release date. Only for an app that isn’t released yet; \
                App Review approves it first.
                """)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        ForEach(problems, id: \.self) { problem in
            InlineMessage.error(problem.message)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { model.isAvailabilitySheetPresented = false }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("pricing.availabilitySetup.cancel")
            Button("Add to Review & Push") { model.queueSetup(setup) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(territories.isEmpty || !problems.isEmpty)
                .accessibilityIdentifier("pricing.availabilitySetup.add")
        }
        .buttonBorderShape(.capsule)
        .padding(.horizontal, Spacing.xLarge)
        .padding(.vertical, Spacing.medium)
    }
}

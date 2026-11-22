//
//  AppPriceSheet.swift
//  Atlas
//

import SwiftUI

/// Add Pricing… / Change Price…: the base country or region (the United
/// States unless the app's price is set elsewhere) and one of Apple's
/// price points there, Free first, each with its customer price and
/// proceeds. Add to Review & Push queues a new price schedule from today.
struct AppPriceSheet: View {
    @Bindable var model: AppPriceAvailabilityModel

    @State private var territoryID: String
    /// The chosen point's App Store Connect ID.
    @State private var pointID: String?
    @State private var search = ""

    init(model: AppPriceAvailabilityModel) {
        self.model = model
        let queued = model.queuedPrice?.requests.first.flatMap(AppPriceAvailabilityRequests.priceSchedule(in:))
        _territoryID = State(initialValue: queued?.baseTerritoryID ?? model.defaultBaseTerritory.id)
        _pointID = State(initialValue: queued?.pricePointID ?? model.price.value?.current?.point?.appStoreConnectID)
    }

    private var ladder: PricePointLadder? {
        model.ladder(for: territoryID).value
    }

    private var territory: AppTerritory {
        let listed = model.territories.value?.first { $0.id == territoryID }
        return AppTerritory(id: territoryID, currencyCode: ladder?.currencyCode ?? listed?.currencyCode)
    }

    private var options: [AppTerritory] {
        let listed = model.territories.value ?? []
        return listed.contains { $0.id == territoryID } ? listed : [territory] + listed
    }

    private var selectedPoint: PricePoint? {
        ladder?.points.first { $0.appStoreConnectID == pointID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                header
                Picker("Base country or region", selection: $territoryID) {
                    ForEach(options) { option in
                        Text(option.name).tag(option.id)
                    }
                }
                .accessibilityIdentifier("pricing.appPriceSheet.territory")
                points
                notes
            }
            .padding(Spacing.xLarge)
            Divider()
            footer
        }
        .frame(width: 480)
        .task { await model.loadTerritories() }
        .task(id: territoryID) { await model.loadLadder(for: territoryID) }
        .onChange(of: territoryID) { pointID = nil }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.appPriceSheet")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(model.price.value?.current == nil ? String(localized: "Add Pricing") : String(localized: "Change Price"))
                .font(.title2.weight(.semibold))
            Text("""
            \(model.app.name)’s price in the base country or region. Apple sets the equalized price everywhere else \
            and keeps it in line with taxes and exchange rates.
            """)
            .font(.callout)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var points: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            TextField("Find a price", text: $search, prompt: Text("Find a price, e.g. 2.99"))
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .accessibilityIdentifier("pricing.appPriceSheet.search")
            Group {
                switch model.ladder(for: territoryID) {
                case .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case let .failed(message):
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        InlineMessage.error(message)
                        Button("Try Again") { Task { await model.loadLadder(for: territoryID) } }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(Spacing.small)
                case let .loaded(ladder):
                    list(ladder)
                }
            }
            .frame(height: 260)
            .background(Palette.content, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        }
    }

    private func list(_ ladder: PricePointLadder) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(shown(ladder), id: \.self) { point in
                        RadioRow(
                            title: AppPriceText.price(point.customerPrice, currencyCode: ladder.currencyCode),
                            detail: point.customerPrice == 0
                                ? String(localized: "No proceeds")
                                : AppPriceText.proceeds(point.proceeds, currencyCode: ladder.currencyCode),
                            isSelected: point.appStoreConnectID == pointID
                        ) {
                            pointID = point.appStoreConnectID
                        }
                        .id(point.appStoreConnectID)
                        .accessibilityIdentifier("pricing.appPriceSheet.point.\(NSDecimalNumber(decimal: point.customerPrice).stringValue)")
                    }
                }
                .padding(.vertical, Spacing.xxSmall)
            }
            .onAppear {
                if let pointID { proxy.scrollTo(pointID, anchor: .center) }
            }
        }
    }

    private func shown(_ ladder: PricePointLadder) -> [PricePoint] {
        let wanted = search.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !wanted.isEmpty else { return ladder.points }
        return ladder.points.filter { NSDecimalNumber(decimal: $0.customerPrice).stringValue.hasPrefix(wanted) }
    }

    @ViewBuilder
    private var notes: some View {
        if let current = model.price.value?.current, current.replacesMoreThanThePrice {
            InlineMessage.warning(String(localized: """
            The new schedule replaces the prices set by hand in \(current.otherManualTerritoryIDs.count) other countries or regions \
            and \(current.laterChangeCount) scheduled changes.
            """))
        }
        if let point = selectedPoint, point.customerPrice > 0 {
            Text("A paid price needs the Paid Applications agreement to be active in App Store Connect → Business.")
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            if let point = selectedPoint {
                Text(AppPriceText.newPrice(point.customerPrice, in: territory))
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
            }
            Spacer()
            Button("Cancel") { model.isPriceSheetPresented = false }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("pricing.appPriceSheet.cancel")
            Button("Add to Review & Push") {
                guard let point = selectedPoint else { return }
                model.queuePrice(point, in: territory)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(selectedPoint == nil)
            .accessibilityIdentifier("pricing.appPriceSheet.add")
        }
        .buttonBorderShape(.capsule)
        .padding(.horizontal, Spacing.xLarge)
        .padding(.vertical, Spacing.medium)
    }
}

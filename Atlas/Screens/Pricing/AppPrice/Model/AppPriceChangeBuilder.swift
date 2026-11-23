//
//  AppPriceChangeBuilder.swift
//  Atlas
//

import Foundation

/// Turns a price for the app itself into one Review & Push change, shown
/// as "Set up the app’s price" (or "Change the app’s price") with its base
/// country or region, price and proceeds. It's one `POST
/// /v1/appPriceSchedules` (`AppPriceAvailabilityRequests`): a schedule
/// from today that replaces the old one. Restoring puts the old base price
/// back when nothing else (prices set by hand elsewhere, later changes)
/// would be lost.
struct AppPriceChangeBuilder {
    let app: StoreApp

    static let idPrefix = "appPrice."

    /// `appPrice.<appID>`: a later price replaces the queued one.
    static func changeID(appID: StoreApp.ID) -> PendingChange.ID {
        "\(idPrefix)\(appID)"
    }

    static func owns(_ change: PendingChange) -> Bool {
        change.id.hasPrefix(idPrefix)
    }

    @MainActor
    static func queued(in queue: ChangeQueue, appID: StoreApp.ID) -> PendingChange? {
        queue.change(id: changeID(appID: appID))
    }

    var group: String { String(localized: "Pricing · App price") }

    func change(
        point: PricePoint,
        in territory: AppTerritory,
        replacing current: AppPriceState,
        source: ChangeSource = .you,
        reason: String? = nil,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let id = Self.changeID(appID: app.id)
        let existing = current.current
        let requests = point.appStoreConnectID.map {
            [AppPriceAvailabilityRequests.priceSchedule(appID: app.id, baseTerritoryID: territory.id, pricePointID: $0)]
        } ?? []
        var change = PendingChange(
            id: id,
            appID: app.id,
            section: .subscriptionPricing,
            group: group,
            title: String(localized: "App price"),
            flagRegion: territory.alpha2,
            oldValue: existing.map { AppPriceText.price($0.point?.customerPrice ?? 0, in: AppTerritory(id: $0.baseTerritoryID, currencyCode: $0.currencyCode)) }
                ?? String(localized: "No price"),
            newValue: AppPriceText.newPrice(point.customerPrice, in: territory),
            source: source,
            blockedReason: point.appStoreConnectID == nil
                ? String(localized: "No Apple price point for this price. Choose it again in Pricing.")
                : nil,
            requests: requests,
            restoreRequests: restoreRequests(for: current),
            createdAt: date
        )
        change.creation = PendingCreation(
            id: id,
            title: existing == nil ? String(localized: "Set up the app’s price") : String(localized: "Change the app’s price"),
            detail: [detail(point: point, current: current), reason].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " "),
            source: source,
            fields: fields(point: point, territory: territory, current: existing, source: source, evidence: evidence)
        )
        return change
    }

    /// The old base price back, when that's all the schedule had.
    private func restoreRequests(for current: AppPriceState) -> [PushRequest] {
        guard let existing = current.current, !existing.replacesMoreThanThePrice, let pointID = existing.point?.appStoreConnectID else { return [] }
        return [AppPriceAvailabilityRequests.priceSchedule(appID: app.id, baseTerritoryID: existing.baseTerritoryID, pricePointID: pointID)]
    }

    private func detail(point: PricePoint, current: AppPriceState) -> String {
        var parts: [String] = []
        if let existing = current.current {
            parts.append(String(localized: "A new price schedule for \(app.name), starting once Apple processes it."))
            if !existing.otherManualTerritoryIDs.isEmpty || existing.laterChangeCount > 0 {
                parts.append(String(localized: """
                Replaces hand-set prices in \(existing.otherManualTerritoryIDs.count) other countries or regions and \
                \(existing.laterChangeCount) scheduled changes.
                """))
            }
        } else {
            parts.append(String(localized: "\(app.name)’s first price, starting once Apple processes it."))
        }
        if point.customerPrice == 0 {
            parts.append(String(localized: "Free in every country or region."))
        } else {
            parts.append(String(localized: """
            Elsewhere, Apple’s automatic prices apply. A paid price needs an active Paid Applications agreement (App Store Connect → \
            Business).
            """))
        }
        return parts.joined(separator: " ")
    }

    private func fields(
        point: PricePoint,
        territory: AppTerritory,
        current: AppCurrentPrice?,
        source: ChangeSource,
        evidence: [String]
    ) -> [PendingChangePart] {
        let part = { (id: String, title: String, old: String, new: String) in
            PendingChangePart(id: id, title: title, oldValue: old, newValue: new, source: source)
        }
        let oldBase = current.map { AppTerritory.name(of: $0.baseTerritoryID) } ?? ""
        var fields = [
            part("baseTerritory", String(localized: "Base country or region"), oldBase, territory.name),
            part(
                "price", String(localized: "Price"), current?.formattedPrice ?? "",
                AppPriceText.price(point.customerPrice, currencyCode: territory.currencyCode)
            ),
        ]
        if point.customerPrice > 0 {
            let old = current?.point.map { CurrencyFormat.forCurrency(current?.currencyCode ?? "USD").format($0.proceeds) } ?? ""
            fields.append(part("proceeds", String(localized: "Proceeds"), old, CurrencyFormat.forCurrency(territory.currencyCode).format(point.proceeds)))
        }
        if !evidence.isEmpty { fields.append(part("evidence", String(localized: "Found in"), "", evidence.joined(separator: "\n"))) }
        return fields
    }
}

//
//  AppAvailabilityChangeBuilder.swift
//  Atlas
//

import Foundation

/// Turns where the app is sold into Review & Push changes:
///
/// - The first availability, one change shown as "Set up availability"
///   with its countries and regions, new ones and pre-order: `POST
///   /v2/appAvailabilities`. Apple has no way to delete it, so there's
///   nothing to restore.
/// - Once it exists, one change per country or region turned on or off,
///   "Availability · Brazil": `PATCH /v1/territoryAvailabilities/{id}`,
///   restored by the opposite `PATCH`.
///
/// `AppPriceAvailabilityRequests` builds the writes.
struct AppAvailabilityChangeBuilder {
    let app: StoreApp

    static let idPrefix = "appAvailability."

    /// `appAvailability.<appID>.setup`.
    static func setupChangeID(appID: StoreApp.ID) -> PendingChange.ID {
        "\(idPrefix)\(appID).setup"
    }

    /// `appAvailability.<appID>.<territoryID>`.
    static func territoryChangeID(appID: StoreApp.ID, territoryID: String) -> PendingChange.ID {
        "\(idPrefix)\(appID).\(territoryID)"
    }

    static func owns(_ change: PendingChange) -> Bool {
        change.id.hasPrefix(idPrefix)
    }

    @MainActor
    static func queuedSetup(in queue: ChangeQueue, appID: StoreApp.ID) -> PendingChange? {
        queue.change(id: setupChangeID(appID: appID))
    }

    /// Every territory availability a queued change of the app turns on or
    /// off, by its ID: Pricing's, and App Compliance's "Stop selling".
    @MainActor
    static func queuedTerritoryWrites(in queue: ChangeQueue, appID: StoreApp.ID) -> [String: Bool] {
        var writes: [String: Bool] = [:]
        for change in queue.changes(for: appID) {
            for request in change.requests {
                guard let write = AppPriceAvailabilityRequests.territoryWrite(in: request) else { continue }
                writes[write.territoryAvailabilityID] = write.available
            }
        }
        return writes
    }

    var group: String { String(localized: "Pricing · Availability") }

    func setupChange(
        _ setup: AppAvailabilitySetup,
        problems: [AppAvailabilityProblem] = [],
        source: ChangeSource = .you,
        reason: String? = nil,
        evidence: [String] = [],
        at date: Date = .now
    ) -> PendingChange {
        let id = Self.setupChangeID(appID: app.id)
        var change = PendingChange(
            id: id,
            appID: app.id,
            section: .subscriptionPricing,
            group: group,
            title: String(localized: "Availability"),
            oldValue: String(localized: "Not set up"),
            newValue: setup.territoriesText,
            source: source,
            blockedReason: problems.first?.message,
            requests: [AppPriceAvailabilityRequests.availability(appID: app.id, setup: setup)],
            createdAt: date
        )
        let detail = String(localized: """
        Where \(app.name) is sold. App Store Connect can’t remove an availability once it’s set up: change countries \
        and regions one at a time here after the push.
        """)
        change.creation = PendingCreation(
            id: id,
            title: String(localized: "Set up availability"),
            detail: [detail, reason].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " "),
            source: source,
            fields: fields(of: setup, source: source, evidence: evidence)
        )
        return change
    }

    /// Turns the app on or off in one country or region; nil when that's
    /// already how it is.
    func territoryChange(_ territory: AppTerritoryAvailability, available: Bool, source: ChangeSource = .you, note: String? = nil) -> PendingChange? {
        guard territory.isAvailable != available else { return nil }
        let place = TerritoryCatalog.standard.territory(alpha3: territory.territoryID)
        let state = { (isOn: Bool) in isOn ? String(localized: "Available") : String(localized: "Not available") }
        return PendingChange(
            id: Self.territoryChangeID(appID: app.id, territoryID: territory.territoryID),
            appID: app.id,
            section: .subscriptionPricing,
            group: group,
            groupNote: note,
            title: String(localized: "Availability · \(territory.name)"),
            flagRegion: place?.alpha2,
            oldValue: state(territory.isAvailable),
            newValue: state(available),
            source: source,
            requests: [AppPriceAvailabilityRequests.territory(territory.id, available: available)],
            restoreRequests: [AppPriceAvailabilityRequests.territory(territory.id, available: territory.isAvailable)]
        )
    }

    private func fields(of setup: AppAvailabilitySetup, source: ChangeSource, evidence: [String]) -> [PendingChangePart] {
        let part = { (id: String, title: String, value: String) in
            PendingChangePart(id: id, title: title, oldValue: "", newValue: value, source: source)
        }
        var fields = [
            part("territories", String(localized: "Countries and regions"), setup.territoriesText),
            part("newTerritories", String(localized: "New countries and regions"), setup.availableInNewTerritories
                ? String(localized: "Available automatically")
                : String(localized: "Not available until you add them")),
            part("preOrder", String(localized: "Pre-order"), setup.preOrderReleaseDate.map { String(localized: "On · released \($0)") }
                ?? String(localized: "Off")),
        ]
        if !evidence.isEmpty { fields.append(part("evidence", String(localized: "Found in"), evidence.joined(separator: "\n"))) }
        return fields
    }
}

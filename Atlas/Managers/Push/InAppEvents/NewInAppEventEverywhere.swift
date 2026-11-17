//
//  NewInAppEventEverywhere.swift
//  Atlas
//

import Foundation

/// A new In-App Event's `POST /v1/appEvents` for every country or region:
/// its schedule's territories are `{everyTerritory}`. The push fills in the
/// territories App Store Connect has (`GET /v1/territories`, read once per
/// push, as for a new subscription's availability), not Atlas's own
/// table, which is approximate: App Store Connect refuses some of its
/// territories (Samoa, `ENTITY_ERROR.INVALID_TERRITORY`).
///
/// Events queued before the placeholder list every territory of that table
/// instead; they're sent the same way.
struct NewInAppEventEverywhere: Hashable, Sendable {
    /// The `POST`, with the placeholder.
    var request: PushRequest

    static let placeholder = SubscriptionAvailabilityEverywhere.placeholder

    /// The request when its schedule asks for every territory; nil for any
    /// other request.
    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == InAppEventChangeBuilder.newEventPath, let body = request.body,
              let schedules = Self.attributes(of: body)?["territorySchedules"] as? [[String: Any]],
              schedules.contains(where: { Self.isEverywhere($0["territories"] as? [String] ?? []) })
        else { return nil }
        self.request = request
    }

    /// The placeholder, or every territory of Atlas's table.
    static func isEverywhere(_ territories: [String]) -> Bool {
        territories == [placeholder] || (!territories.isEmpty && Set(territories) == tableIDs)
    }

    private static let tableIDs = Set(TerritoryCatalog.standard.territories.map(\.id))

    /// The `POST` with `territoryIDs` in every schedule that asked for
    /// every territory.
    func request(territoryIDs: [String]) -> PushRequest {
        guard var object = request.body.flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }),
              var data = object["data"] as? [String: Any],
              var attributes = data["attributes"] as? [String: Any],
              let schedules = attributes["territorySchedules"] as? [[String: Any]]
        else { return request }
        attributes["territorySchedules"] = schedules.map { schedule in
            guard Self.isEverywhere(schedule["territories"] as? [String] ?? []) else { return schedule }
            var filled = schedule
            filled["territories"] = territoryIDs
            return filled
        }
        data["attributes"] = attributes
        object["data"] = data
        var filled = request
        filled.body = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])) ?? request.body
        return filled
    }

    private static func attributes(of body: Data) -> [String: Any]? {
        let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        return (object?["data"] as? [String: Any])?["attributes"] as? [String: Any]
    }
}

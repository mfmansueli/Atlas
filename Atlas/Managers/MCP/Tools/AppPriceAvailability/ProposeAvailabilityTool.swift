//
//  ProposeAvailabilityTool.swift
//  Atlas
//

import Foundation

/// `propose_availability`: where the app is sold, queued in Review & Push
/// as the assistant's. An app without an availability gets its first one
/// ("Set up availability": every territory by default, new ones too, an
/// optional pre-order), as Set Up Availability… queues it; one that has
/// it gets a change per territory turned on or off.
struct ProposeAvailabilityTool: MCPTool {
    /// The arguments, typed apart so the definition type-checks quickly.
    private static let properties: [String: JSONValue] = MCPToolDefinition.withLayers([
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "territories": [
            "type": ["array", "string"],
            "items": ["type": "string"],
            "description": "First availability only: \"all\" (the default) or territory codes, e.g. [\"USA\", \"BR\"].",
        ],
        "availableInNewTerritories": ["type": "boolean", "description": "First availability only: whether new territories get it (default true)."],
        "preOrderReleaseDate": MCPToolDefinition.string("First availability only: offer a pre-order until this release date, YYYY-MM-DD."),
        "makeAvailable": ["type": "array", "items": ["type": "string"], "description": "Territories to start selling in, e.g. [\"CHN\"]."],
        "makeUnavailable": ["type": "array", "items": ["type": "string"], "description": "Territories to stop selling in."],
        "reason": MCPToolDefinition.why("Why, in a sentence the person can check."),
        "evidence": ["type": "array", "items": ["type": "string"], "description": "e.g. README.md:30 — “Available in the US and Canada”"],
    ])

    let definition = MCPToolDefinition(
        name: "propose_availability",
        title: "Propose where the app is sold",
        description: """
        Proposes where an app is sold. For an app without an availability (get_app_price_and_availability: \
        availability.state "notSet"), it queues its first one: territories ("all" by default, or codes), \
        availableInNewTerritories (default true) and an optional pre-order until preOrderReleaseDate (YYYY-MM-DD, \
        2 to 180 days away, for an app that isn't released yet). App Store Connect can't remove an availability \
        once it's set up. For an app that has one, makeAvailable and makeUnavailable queue one change per territory. \
        Changes wait in Review & Push (status "queued") until the person pushes; "unchanged" means nothing would \
        change, and "refused" says why. Give a reason and evidence.
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId"]),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let sale = try await MCPAppPriceAvailability.load(app: arguments.string("appId"), in: context.workspace)
        let target = "\(sale.app.name) · Availability"
        let reason = try MCPAppPriceAvailability.reason(arguments)
        switch try await sale.availability() {
        case .notSet:
            return try await setUp(sale, arguments: arguments, reason: reason, target: target, context: context)
        case let .set(availability):
            if arguments.values["territories"] != nil || arguments.values["preOrderReleaseDate"] != nil
                || arguments.values["availableInNewTerritories"] != nil
            {
                let message = String(localized: """
                \(sale.app.name) already has an availability: change territories with makeAvailable and makeUnavailable. \
                Apple's API can't change new territories or pre-orders of an existing availability.
                """)
                return .refused(message, target: target)
            }
            return try change(availability, sale: sale, arguments: arguments, reason: reason, target: target, context: context)
        }
    }

    // MARK: - First availability

    private func setUp(
        _ sale: MCPAppPriceAvailability,
        arguments: MCPToolArguments,
        reason: String?,
        target: String,
        context: MCPToolContext
    ) async throws -> MCPToolOutcome {
        let ids = try await sale.territories().map(\.id)
        var setup = AppAvailabilitySetup.everywhere(ids)
        if let chosen = try Self.chosenTerritories(arguments) {
            var unknown: [String] = []
            var available: Set<String> = []
            for code in chosen {
                if let id = MCPAppPriceAvailability.territoryID(matching: code, among: ids) { available.insert(id) } else { unknown.append(code) }
            }
            guard unknown.isEmpty else {
                return .refused(String(localized: "App Store Connect has no territory \(unknown.formatted(.list(type: .and)))."), target: target)
            }
            setup.availableTerritoryIDs = available
        }
        setup.availableInNewTerritories = try arguments.optionalBool("availableInNewTerritories") ?? true
        setup.preOrderReleaseDate = try arguments.optionalString("preOrderReleaseDate")
        let problems = AppAvailabilityRules.problems(for: setup, today: .now)
        guard problems.isEmpty else {
            return .refused(problems.map(\.message).joined(separator: " "), target: target)
        }
        let id = AppAvailabilityChangeBuilder.setupChangeID(appID: sale.app.id)
        if let queued = sale.queue.change(id: id), queued.source != context.source {
            return .refused(String(localized: "\(queued.source.title) already queued an availability for \(sale.app.name) in Review & Push."), target: target)
        }
        let evidence = try arguments.optionalStrings("evidence") ?? []
        let layers = try arguments.layers()
        let change = AppAvailabilityChangeBuilder(app: sale.app).setupChange(setup, source: context.source, reason: reason, evidence: evidence)
        sale.queue.upsert(change)
        sale.queue.attach(layers, to: change.id)
        let result: JSONValue = [
            "status": "queued",
            "changeId": .string(id),
            "value": .string(change.newValue),
            "note": "It waits in Review & Push until the person pushes; App Store Connect then sets up the availability.",
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// `territories` as codes; nil for "all" or when left out.
    private static func chosenTerritories(_ arguments: MCPToolArguments) throws -> [String]? {
        guard let value = arguments.values["territories"], !value.isNull else { return nil }
        if let text = value.stringValue {
            if text.trimmingCharacters(in: .whitespaces).lowercased() == "all" { return nil }
            return [text]
        }
        guard let codes = try arguments.optionalStrings("territories") else { return nil }
        return codes
    }

    // MARK: - Existing availability

    private func change(
        _ availability: AppAvailability,
        sale: MCPAppPriceAvailability,
        arguments: MCPToolArguments,
        reason: String?,
        target: String,
        context: MCPToolContext
    ) throws -> MCPToolOutcome {
        let turnOn = try arguments.optionalStrings("makeAvailable") ?? []
        let turnOff = try arguments.optionalStrings("makeUnavailable") ?? []
        guard !turnOn.isEmpty || !turnOff.isEmpty else {
            return .refused(String(localized: "Name territories in makeAvailable or makeUnavailable."), target: target)
        }
        let ids = availability.territories.map(\.territoryID)
        var wanted: [(AppTerritoryAvailability, Bool)] = []
        var reasons: [String] = []
        for (codes, isOn) in [(turnOn, true), (turnOff, false)] {
            for code in codes {
                guard let id = MCPAppPriceAvailability.territoryID(matching: code, among: ids), let territory = availability.territory(id) else {
                    reasons.append(String(localized: "\(sale.app.name)’s availability has no territory “\(code)”."))
                    continue
                }
                wanted.append((territory, isOn))
            }
        }
        let builder = AppAvailabilityChangeBuilder(app: sale.app)
        let note = reason.map { String(localized: "\(context.clientName): \($0)") }
        var changes: [PendingChange] = []
        for (territory, isOn) in wanted {
            guard let change = builder.territoryChange(territory, available: isOn, source: context.source, note: note) else { continue }
            if let queued = sale.queue.change(id: change.id), queued.source != context.source {
                reasons.append(String(localized: "\(queued.source.title) already queued \(territory.name) in Review & Push."))
                continue
            }
            changes.append(change)
        }
        guard reasons.isEmpty else {
            return .refused(reasons.joined(separator: " "), target: target)
        }
        guard !changes.isEmpty else {
            return MCPToolOutcome(result: ["status": "unchanged"], isError: false, logLines: [.init(target: target, outcome: .read)])
        }
        let layers = try arguments.layers()
        sale.queue.upsert(contentsOf: changes)
        sale.queue.attach(layers, to: changes.map(\.id))
        let result: JSONValue = [
            "status": "queued",
            "changeIds": .array(changes.map { .string($0.id) }),
            "note": "They wait in Review & Push until the person pushes.",
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }
}

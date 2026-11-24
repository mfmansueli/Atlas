//
//  ProposeNominationTool+Arguments.swift
//  Atlas
//

import Foundation

// `propose_nomination`'s arguments over a nomination's content: what's
// sent replaces the field, what's left out stays (a new nomination starts
// empty, on the open app). A value that isn't one at all (an unknown type,
// a date that isn't one) throws; one Atlas can't keep is a problem the
// refusal lists.
extension ProposeNominationTool {
    struct Parsed {
        var content: NominationContent
        var problems: [String] = []
    }

    static func content(from arguments: MCPToolArguments, over base: NominationContent, model: NominationsViewModel) throws -> Parsed {
        var parsed = Parsed(content: base)
        try texts(arguments, into: &parsed.content)
        try dates(arguments, into: &parsed.content)
        try reach(arguments, into: &parsed)
        try links(arguments, into: &parsed, model: model)
        if !parsed.content.appIDs.contains(model.app.id) { parsed.content.appIDs.insert(model.app.id, at: 0) }
        if !NominationLink.links(in: parsed.content.description).isEmpty {
            parsed.problems.append(String(
                localized: "The description has a link, which Apple refuses. Put links in supplementalMaterialsUris.", comment: "kind:error"
            ))
        }
        return parsed
    }

    /// The name, type, description and notes.
    private static func texts(_ arguments: MCPToolArguments, into content: inout NominationContent) throws {
        if let name = try arguments.optionalString("name") { content.name = name }
        if let type = try arguments.optionalString("type") {
            let key = type.uppercased().replacingOccurrences(of: " ", with: "_")
            guard let value = NominationType(rawValue: key) else {
                throw MCPToolError.invalidArgument(name: "type", expected: "APP_LAUNCH, APP_ENHANCEMENTS or NEW_CONTENT")
            }
            content.type = value
        }
        if let description = try arguments.optionalString("description") { content.description = description }
        if let notes = try arguments.optionalString("notes") { content.notes = notes }
    }

    /// The start, and the end (an empty string clears it).
    private static func dates(_ arguments: MCPToolArguments, into content: inout NominationContent) throws {
        if let start = try arguments.optionalString("publishStartDate") {
            guard let date = MCPNominations.date(start) else {
                throw MCPToolError.invalidArgument(name: "publishStartDate", expected: MCPNominations.dateExpected)
            }
            content.publishStart = date
        }
        guard let end = try arguments.optionalString("publishEndDate") else { return }
        guard !end.isEmpty else {
            content.publishEnd = nil
            return
        }
        guard let date = MCPNominations.date(end) else {
            throw MCPToolError.invalidArgument(name: "publishEndDate", expected: MCPNominations.dateExpected)
        }
        content.publishEnd = date
    }

    /// Devices, languages, countries and how it starts.
    private static func reach(_ arguments: MCPToolArguments, into parsed: inout Parsed) throws {
        if let names = try arguments.optionalStrings("deviceFamilies") {
            let devices = names.map { (name: $0, device: NominationDevice(rawValue: $0.uppercased())) }
            parsed.content.devices = unique(devices.compactMap(\.device))
            parsed.problems += devices.filter { $0.device == nil }.map {
                String(localized: "“\($0.name)” isn’t a device family. Use IPHONE, IPAD, MAC, APPLE_WATCH, APPLE_TV or VISION.", comment: "kind:error")
            }
        }
        if let codes = try arguments.optionalStrings("locales") {
            let locales = codes.map { (code: $0, locale: StoreLocaleCatalog.locale(code: $0)) }
            parsed.content.locales = unique(locales.compactMap(\.locale?.code))
            parsed.problems += locales.filter { $0.locale == nil }.map {
                String(localized: "“\($0.code)” isn’t an App Store Connect locale. Use codes like en-US or pt-BR.", comment: "kind:error")
            }
        }
        if let codes = try arguments.optionalStrings("territories") {
            let territories = codes.map { (code: $0, territory: TerritoryCatalog.standard.territory(code: $0)) }
            let ids = unique(territories.compactMap(\.territory?.id))
            parsed.content.territories = NewInAppEventEverywhere.isEverywhere(ids) ? [] : ids
            parsed.problems += territories.filter { $0.territory == nil }.map {
                String(localized: "“\($0.code)” isn’t a country or region code. Use App Store Connect’s, e.g. USA or BRA.", comment: "kind:error")
            }
        }
        if let first = try arguments.optionalBool("launchInSelectMarketsFirst") { parsed.content.launchInSelectMarketsFirst = first }
        if let preOrder = try arguments.optionalBool("preOrderEnabled") { parsed.content.preOrderEnabled = preOrder }
    }

    /// Linked events, materials and the other apps it covers.
    private static func links(_ arguments: MCPToolArguments, into parsed: inout Parsed, model: NominationsViewModel) throws {
        if let ids = try arguments.optionalStrings("inAppEventIds") {
            let events = ids.map { id in (id: id, event: model.context.events.first { $0.id == id || $0.name.lowercased() == id.lowercased() }) }
            parsed.content.eventIDs = unique(events.compactMap(\.event?.id))
            parsed.problems += events.filter { $0.event == nil }.map {
                String(localized: "“\($0.id)” isn’t one of the app’s In-App Events. Read get_in_app_events for their ids.", comment: "kind:error")
            }
        }
        if let links = try arguments.optionalStrings("supplementalMaterialsUris") {
            parsed.content.materials = links.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        if let identifiers = try arguments.optionalStrings("otherAppIds") {
            let apps = identifiers.map { identifier in
                (identifier: identifier, app: model.context.apps.first { [$0.id, $0.bundleID, $0.name].contains(identifier) })
            }
            parsed.content.appIDs = unique([model.app.id] + apps.compactMap(\.app?.id))
            parsed.problems += apps.filter { $0.app == nil }.map {
                String(localized: "“\($0.identifier)” isn’t one of the account’s apps. Use an id from list_apps.", comment: "kind:error")
            }
        }
    }

    private static func unique<Value: Hashable>(_ values: [Value]) -> [Value] {
        var seen: Set<Value> = []
        return values.filter { seen.insert($0).inserted }
    }
}

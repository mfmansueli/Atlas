//
//  ProposeInAppEventTool+Arguments.swift
//  Atlas
//

import Foundation

// `propose_in_app_event`'s arguments as a new event. An argument that isn't
// usable at all (an unknown badge, a date that isn't one, an unknown
// primary language) throws; a text or territory that can't be kept is a
// problem the refusal lists with the event's own.
extension ProposeInAppEventTool {
    struct Proposal {
        var event: NewInAppEvent
        /// What's wrong with its texts and territories, each saying how to
        /// fix it.
        var problems: [String] = []
    }

    static func proposal(from arguments: MCPToolArguments, app: StoreApp) throws -> Proposal {
        var event = NewInAppEvent()
        event.referenceName = try arguments.optionalString("referenceName") ?? ""
        event.badge = try value(InAppEventBadge.self, "badge", in: arguments) ?? event.badge
        event.purpose = try value(InAppEventPurpose.self, "purpose", in: arguments) ?? event.purpose
        event.priority = try value(InAppEventPriority.self, "priority", in: arguments) ?? event.priority
        event.purchaseRequirement = try value(InAppEventPurchaseRequirement.self, "purchaseRequirement", in: arguments) ?? event.purchaseRequirement
        event.deepLink = try arguments.optionalString("deepLink") ?? ""
        let primary = try arguments.optionalString("primaryLocale") ?? app.primaryLocale ?? StoreLocale.englishUS.code
        guard let locale = StoreLocaleCatalog.locale(code: primary) else {
            throw MCPToolError.invalidArgument(name: "primaryLocale", expected: String(localized: "an App Store Connect locale code, e.g. en-US"))
        }
        event.primaryLocale = locale.code
        event.publishStart = try Self.date("publishStart", in: arguments)
        event.eventStart = try Self.date("eventStart", in: arguments)
        event.eventEnd = try Self.date("eventEnd", in: arguments)

        var proposal = Proposal(event: event)
        let territories = try Self.territories(in: arguments)
        proposal.event.territories = territories.ids
        proposal.problems += territories.problems
        let texts = try Self.texts(in: arguments)
        proposal.event.texts = texts.texts
        proposal.problems += texts.problems
        return proposal
    }

    /// An enumeration's API value, e.g. `CHALLENGE`; "Challenge" and
    /// "special event" are read as `CHALLENGE` and `SPECIAL_EVENT`. Nil when
    /// it's left out.
    private static func value<Value: RawRepresentable & CaseIterable>(
        _: Value.Type, _ name: String, in arguments: MCPToolArguments
    ) throws -> Value? where Value.RawValue == String {
        guard let text = try arguments.optionalString(name) else { return nil }
        let key = text.uppercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")
        guard let value = Value(rawValue: key) else {
            let names = Value.allCases.map(\.rawValue).joined(separator: ", ")
            throw MCPToolError.invalidArgument(name: name, expected: String(localized: "one of \(names)"))
        }
        return value
    }

    private static func date(_ name: String, in arguments: MCPToolArguments) throws -> Date {
        guard let date = try AppStoreConnectDate.date(arguments.optionalString(name)) else {
            throw MCPToolError.invalidArgument(name: name, expected: String(localized: """
            an ISO 8601 date and time with its time zone, e.g. 2027-01-01T00:00:00Z or 2027-01-31T23:59:00-03:00 (a date \
            alone doesn’t say when on that day)
            """))
        }
        return date
    }

    /// App Store Connect's IDs for the codes (`USA`, or `US`), in order,
    /// without repeats; none for every country or region.
    private static func territories(in arguments: MCPToolArguments) throws -> (ids: [String], problems: [String]) {
        var ids: [String] = []
        var problems: [String] = []
        for code in try arguments.optionalStrings("territories") ?? [] {
            guard let territory = TerritoryCatalog.standard.territory(code: code) else {
                problems.append(String(localized: "“\(code)” isn’t a country or region code. Use App Store Connect’s, e.g. USA or BRA."))
                continue
            }
            if !ids.contains(territory.id) { ids.append(territory.id) }
        }
        return (NewInAppEventEverywhere.isEverywhere(ids) ? [] : ids, problems)
    }

    /// `texts` by locale, each language with all three texts, trimmed. Also
    /// takes a list of `{locale, name, shortDescription, longDescription}`,
    /// as `propose_event_texts` does.
    private static func texts(in arguments: MCPToolArguments) throws -> (texts: [String: [InAppEventField: String]], problems: [String]) {
        guard let value = arguments.values["texts"], !value.isNull else { return ([:], []) }
        var entries: [(locale: String, texts: JSONValue)] = []
        if let object = value.objectValue {
            entries = object.keys.sorted().compactMap { locale in object[locale].map { (locale, $0) } }
        } else if let array = value.arrayValue {
            entries = array.map { ($0["locale"]?.stringValue ?? "", $0) }
        } else {
            throw MCPToolError.invalidArgument(name: "texts", expected: String(localized: """
            an object by locale, e.g. {"en-US": {"name": …, "shortDescription": …, "longDescription": …}}
            """))
        }
        var texts: [String: [InAppEventField: String]] = [:]
        var problems: [String] = []
        for entry in entries {
            let locale = entry.locale.trimmingCharacters(in: .whitespacesAndNewlines)
            guard StoreLocaleCatalog.locale(code: locale) != nil else {
                problems.append(String(localized: "“\(locale)” isn’t an App Store locale code, e.g. en-US."))
                continue
            }
            var fields: [InAppEventField: String] = [:]
            for field in InAppEventField.allCases {
                fields[field] = (entry.texts[field.rawValue]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let empty = InAppEventField.allCases.first(where: { fields[$0]?.isEmpty ?? true }) {
                problems.append(String(localized: "\(locale) · \(empty.rawValue) is empty: send all three texts."))
            }
            texts[locale] = fields
        }
        return (texts, problems)
    }
}

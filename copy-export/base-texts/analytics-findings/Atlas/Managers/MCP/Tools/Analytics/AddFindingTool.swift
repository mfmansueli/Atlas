//
//  AddFindingTool.swift
//  Atlas
//

import Foundation

struct AddFindingTool: MCPTool {
    var store = AnalyticsStore.shared

    static let titleLimit = 140
    static let whyLimit = 400

    let definition = MCPToolDefinition(
        name: "add_finding",
        title: "Add an Analytics finding",
        description: """
        Adds a finding to an app's Analytics → What to Try, marked as yours: one thing the numbers say is worth changing. \
        Give `title` (what you saw, one sentence, ≤140 characters), `why` (the likely cause and why the fix helps, ≤400), \
        `area` (storePage, screenshots, pricing, retention, inAppTexts, productPages, stability or billing: the section \
        where the fix is made), `howSure` (the counts and range behind it, from the get_analytics_ tools; say when a number \
        is small), `read` (what you read for it: the tools, reports or files, shown under the finding) and up to three \
        `numbers` ({label, value, note}). Optional `locale` or `territory` (alpha-2) opens that section on the right \
        language or country, and `page` a custom product page by name. Only say what the numbers support, and don't repeat \
        a finding get_analytics_funnel already lists. `id` \
        replaces a finding you added before. A finding changes nothing on the App Store: send the fix itself with the \
        propose_ and suggest_ tools.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "title": MCPToolDefinition.string("What you saw, in one sentence."),
                "why": MCPToolDefinition.string("The likely cause, and why the fix should help."),
                "area": MCPToolDefinition.string("storePage, screenshots, pricing, retention, inAppTexts, productPages, stability or billing."),
                "read": [
                    "type": "array", "description": "What you read for it, e.g. get_analytics_retention, Retention Messaging, PaywallView.swift.",
                    "items": ["type": "string"],
                ],
                "page": MCPToolDefinition.string("A custom product page's name, for productPages."),
                "howSure": MCPToolDefinition.string("The counts and the range behind it."),
                "sureness": MCPToolDefinition.string("sure, fairlySure or rough. Leave it out for fairlySure."),
                "numbers": ["type": "array", "description": "Up to three {label, value, note} objects.", "items": ["type": "object"]],
                "locale": MCPToolDefinition.string("A store page locale code such as de-DE, for storePage and screenshots."),
                "territory": MCPToolDefinition.string("A territory's alpha-2 code such as BR, for pricing."),
                "id": MCPToolDefinition.string("The id of a finding you added before, to replace it."),
            ],
            required: ["appId", "title", "why", "area", "howSure"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let target = "\(app.name) · Finding"
        let title = try arguments.string("title").trimmingCharacters(in: .whitespacesAndNewlines)
        let why = try arguments.string("why").trimmingCharacters(in: .whitespacesAndNewlines)
        let howSure = try arguments.string("howSure").trimmingCharacters(in: .whitespacesAndNewlines)
        let locale = try arguments.optionalString("locale")
        let territory = try arguments.optionalString("territory").map { $0.uppercased() }
        if let reason = refusal(title: title, why: why, howSure: howSure, locale: locale, territory: territory, app: app) {
            return .refused(reason, target: target)
        }
        let id = try arguments.optionalString("id") ?? "assistant.\(UUID().uuidString.prefix(8).lowercased())"
        var action = try Self.action(area: arguments.string("area"), locale: locale, territory: territory)
        if case .productPage = action, let page = try arguments.optionalString("page") { action = .productPage(name: page) }
        let read = try arguments.optionalStrings("read")
        try store.add(
            AnalyticsFinding(
                id: id, source: .assistant(context.clientName), title: title, why: why, numbers: Self.numbers(arguments),
                sureness: Self.sureness(arguments), surenessDetail: howSure,
                action: action, date: store.now(), read: read.map { Array($0.prefix(8)) }
            ),
            for: app.id
        )
        return MCPToolOutcome(
            result: ["status": "added", "id": .string(id), "showsIn": "Analytics → What to Try"],
            isError: false,
            logLines: [MCPToolOutcome.LogLine(target: target, outcome: .proposed)]
        )
    }

    /// Why the finding can't be kept, in words the assistant can act on.
    private func refusal(title: String, why: String, howSure: String, locale: String?, territory: String?, app: StoreApp) -> String? {
        if title.isEmpty || title.count > Self.titleLimit {
            return "title has \(title.count) characters; it needs 1 to \(Self.titleLimit)."
        }
        if why.isEmpty || why.count > Self.whyLimit {
            return "why has \(why.count) characters; it needs 1 to \(Self.whyLimit)."
        }
        if howSure.isEmpty { return "howSure is empty: give the counts behind the finding." }
        if store.setup(for: app.id) != .ready {
            return "Analytics has no numbers for \(app.name) yet, so there is nothing a finding could rest on."
        }
        if let locale, StoreLocaleCatalog.locale(code: locale) == nil { return "“\(locale)” isn't an App Store locale code." }
        if let territory, TerritoryCatalog.standard.territory(alpha2: territory) == nil {
            return "“\(territory)” isn't an App Store territory's alpha-2 code."
        }
        return nil
    }

    private static func action(area: String, locale: String?, territory: String?) throws -> FindingAction {
        switch area {
        case "storePage": .storePage(locale: locale)
        case "screenshots": .screenshots(locale: locale)
        case "pricing": .pricing(territory: territory)
        case "retention": .retention
        case "inAppTexts": .inAppTexts
        case "productPages": .productPage(name: nil)
        case "stability": .stability
        case "billing": .billing
        default:
            throw MCPToolError.invalidArgument(
                name: "area", expected: "storePage, screenshots, pricing, retention, inAppTexts, productPages, stability or billing"
            )
        }
    }

    private static func sureness(_ arguments: MCPToolArguments) throws -> String {
        switch try arguments.optionalString("sureness") ?? "fairlySure" {
        case "sure": String(localized: "Sure")
        case "fairlySure": String(localized: "Fairly sure")
        case "rough": String(localized: "Rough")
        default: throw MCPToolError.invalidArgument(name: "sureness", expected: "sure, fairlySure or rough")
        }
    }

    /// Up to three {label, value, note}.
    private static func numbers(_ arguments: MCPToolArguments) throws -> [FindingNumber] {
        try (arguments.optionalArray("numbers") ?? []).prefix(3).compactMap { value in
            guard let label = value["label"]?.stringValue, let text = value["value"]?.stringValue else { return nil }
            return FindingNumber(label: label, value: text, note: value["note"]?.stringValue)
        }
    }
}

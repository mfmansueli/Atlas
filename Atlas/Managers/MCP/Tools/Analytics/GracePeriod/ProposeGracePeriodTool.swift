//
//  ProposeGracePeriodTool.swift
//  Atlas
//

import Foundation

/// `propose_grace_period`: suggests turning on Billing Grace Period, so
/// subscribers whose charge failed keep access while Apple retries. It
/// waits in Analytics → Subscriptions → Billing and Plans; the person turns
/// it on there after the confirmation. Nothing is turned on here.
struct ProposeGracePeriodTool: MCPTool {
    var store = AnalyticsStore.shared
    var suggestions = GracePeriodSuggestionStore.shared

    let definition = MCPToolDefinition(
        name: "propose_grace_period",
        title: "Suggest Billing Grace Period",
        description: """
        Suggests turning on Billing Grace Period for an app's subscriptions: people whose renewal charge failed keep \
        access for days (3, 16 or 28) while Apple retries, so fewer leave over a card problem. Read \
        get_analytics_subscribers first (lost to billing, gracePeriod on or off) and give why with that number (e.g. \
        “41 subscribers left over failed charges in 28 days.”). Refused when it's already on or the app sells no \
        subscription. It waits in Analytics → Billing and Plans; only the person turns it on, after confirming. \
        withdraw: true takes it back.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "days": ["type": "integer", "enum": [3, 16, 28], "description": "How long people keep access: 3, 16 or 28 days."],
                "why": MCPToolDefinition.why("Why, for the person."),
                "withdraw": ["type": "boolean", "description": "true: take back your suggestion for this app; nothing else is read."],
            ]),
            required: ["appId"]
        ),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let target = String(localized: "\(app.name) · Billing Grace Period", comment: "kind:other")
        guard context.allows(.prices) else { return .refused(MCPProposalKind.prices.refusal, target: target) }
        if try arguments.optionalBool("withdraw") == true {
            guard suggestions.suggestion(for: app.id)?.client == context.clientName else {
                return .refused(String(localized: "No Billing Grace Period suggestion of yours waits for \(app.name).", comment: "kind:error"), target: target)
            }
            suggestions.remove(for: app.id)
            return MCPToolOutcome(result: ["status": "withdrawn"], isError: false, logLines: [.init(target: target, outcome: .proposed)])
        }
        let days = try arguments.optionalInt("days") ?? GracePeriodSetting.Duration.sixteenDays.days
        guard let duration = GracePeriodSetting.Duration.allCases.first(where: { $0.days == days }) else {
            throw MCPToolError.invalidArgument(name: "days", expected: "3, 16 or 28")
        }
        let why = try arguments.string("why")
        let layers = try arguments.layers()
        let summary = try? await context.workspace.services.pricing.summary(for: app)
        if let summary, summary.subscriptionCount == 0 {
            return .refused(String(localized: "\(app.name) sells no subscription, and Billing Grace Period is for subscriptions.", comment: "kind:error"), target: target)
        }
        let setting = try await currentSetting(for: app, in: context)
        if setting?.isOn == true {
            let length = setting?.duration?.title ?? ""
            return .refused(String(localized: "Billing Grace Period is already on for \(app.name) (\(length)).", comment: "kind:error"), target: target)
        }
        suggestions.suggest(GracePeriodSuggestion(appID: app.id, duration: duration, why: why, client: context.clientName, layers: layers))
        let result: JSONValue = [
            "status": "suggested",
            "days": .int(duration.days),
            "note": "It waits in Analytics → Subscriptions → Billing and Plans; the person turns it on after confirming.",
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// The setting as Analytics read it, else as App Store Connect has it.
    private func currentSetting(for app: StoreApp, in context: MCPToolContext) async throws -> GracePeriodSetting? {
        if let known = store.gracePeriods[app.id] { return known }
        do {
            return try await context.workspace.services.analytics.gracePeriod(appID: app.id)
        } catch {
            throw MCPToolError.unavailable(String(localized: "Couldn’t read \(app.name)’s Billing Grace Period: \(error.localizedDescription)", comment: "kind:error"))
        }
    }
}

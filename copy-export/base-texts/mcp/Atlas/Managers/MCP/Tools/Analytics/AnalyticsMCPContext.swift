//
//  AnalyticsMCPContext.swift
//  Atlas
//

import Foundation

/// What the analytics tools read for one app: the facts on this Mac, and
/// what explains them. Tools never download: they answer from what
/// Atlas has, and say when that's nothing.
@MainActor
struct AnalyticsMCPContext {
    let app: StoreApp
    let dataset: AnalyticsDataset
    let context: AnalyticsContext
    let store: AnalyticsStore

    static func load(app identifier: String, in workspace: MCPWorkspace, store: AnalyticsStore) async throws -> AnalyticsMCPContext {
        let app = try await workspace.app(matching: identifier)
        switch store.setup(for: app.id) {
        case .ready:
            break
        case .off:
            throw MCPToolError.unavailable(String(localized: """
            Analytics isn't turned on for \(app.name). The person turns it on in Atlas: Analytics (⌘9) → Ask Apple for \
            Reports. Apple's first reports take 1 to 2 days.
            """))
        case let .waiting(asked):
            throw MCPToolError.unavailable(String(localized: """
            Apple is still preparing \(app.name)'s reports (asked on \(AnalyticsText.day(asked)); they take 1 to 2 days). \
            There are no numbers yet.
            """))
        case .keyCannotAsk:
            throw MCPToolError.unavailable(String(localized: """
            \(app.name)'s reports can't be asked for: the API key isn't an Admin key. The person adds one in Settings → Accounts.
            """))
        }
        let summary = try? await workspace.services.pricing.summary(for: app)
        let dataset = store.dataset(for: app, sellsSubscriptions: summary.map { $0.subscriptionCount > 0 } ?? true)
        let context: AnalyticsContext = if let fixed = workspace.services.analytics.fixedContext {
            fixed
        } else {
            await AnalyticsContextLoader(services: workspace.services).storePage(for: app)
        }
        return AnalyticsMCPContext(app: app, dataset: dataset, context: context, store: store)
    }

    /// 7, 28 or 90; 28 when not given.
    static func days(_ arguments: MCPToolArguments) throws -> Int {
        guard let days = try arguments.optionalInt("days") else { return 28 }
        guard [7, 28, 90].contains(days) else { throw MCPToolError.invalidArgument(name: "days", expected: "7, 28 or 90") }
        return days
    }

    /// The funnel, or the reason there isn't one.
    func funnel(days: Int) throws -> FunnelReport {
        guard let report = FunnelReport.make(dataset, days: days) else {
            throw MCPToolError.unavailable(String(localized: "Atlas has no days of data for \(app.name) yet."))
        }
        return report
    }

    /// What's missing and why, so the assistant can tell the person.
    var notes: [JSONValue] {
        var notes: [String] = [
            "Apple's numbers are 1 to 2 days behind, and rows with fewer than five people are left out, so parts can add up to less than totals.",
        ]
        switch dataset.salesState {
        case .ready: break
        case .needsVendorNumber: notes.append("Trials, paid starts and proceeds are missing: the person hasn't entered the vendor number (Analytics settings).")
        case .keyCannotRead: notes.append("Trials, paid starts and proceeds are missing: the API key's role can't read Sales and Trends.")
        case .waiting: notes.append("Trials, paid starts and proceeds are missing: Sales and Trends hasn't been downloaded yet.")
        }
        if case .waiting = dataset.engagementState {
            notes.append("Impressions, page views and downloads are missing: Apple's analytics reports haven't arrived.")
        }
        if !dataset.sellsSubscriptions { notes.append("The app has no subscription: the funnel ends at downloads.") }
        return notes.map(JSONValue.string)
    }
}

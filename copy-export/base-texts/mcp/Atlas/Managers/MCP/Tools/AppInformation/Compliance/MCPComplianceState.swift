//
//  MCPComplianceState.swift
//  Atlas
//

import Foundation

/// An app's App Compliance page as the tools see it: the same report the
/// page shows (Apple's countries and statuses, the categories and age
/// rating with queued changes on top, the person's answers), the open
/// assistant suggestions, and the trader details Atlas prepares.
@MainActor
struct MCPComplianceState {
    let app: StoreApp
    let report: ComplianceReport
    let notes: AppInformationNotes
    /// The team's name and App Review's contact, as the page prepares them.
    let preparedTraderDetails: TraderDetails
    /// The App Information builder, for the ids of the changes an answer
    /// becomes.
    let builder: AppInformationChangeBuilder

    static func load(_ app: StoreApp, in context: MCPToolContext) async throws -> MCPComplianceState {
        try await load(app, workspace: context.workspace)
    }

    /// `stopsSellingInChina` reads every section's changes: Pricing's
    /// `propose_availability` queues the same change.
    static func load(_ app: StoreApp, workspace: MCPWorkspace) async throws -> MCPComplianceState {
        let services = workspace.services.appInformation
        let content = try await services.content(for: app, versionID: nil)
        let compliance = try await services.compliance(for: app)
        let builder = AppInformationChangeBuilder(appID: app.id, ids: content.ids, versionString: content.version?.versionString)
        let changes = workspace.changes.changes(for: app.id, section: .appInformation)
        let notes = services.notes.notes(for: app.id)
        let report = ComplianceReport(
            appName: app.name,
            content: compliance,
            general: builder.general(content.general, with: changes),
            ageRating: builder.ageRating(content.ageRating, with: changes).answers,
            answers: notes.compliance,
            stopsSellingInChina: builder.stopsSelling(in: ComplianceRegion.chinaMainland, with: workspace.changes.changes(for: app.id))
        )
        let prepared = notes.compliance.traderDetails ?? TraderDetails(
            name: workspace.teamName,
            phone: content.review.phone,
            email: content.review.email
        )
        return MCPComplianceState(app: app, report: report, notes: notes, preparedTraderDetails: prepared, builder: builder)
    }

    /// The open suggestion for `rule`, if an assistant left one.
    func suggestion(for rule: ComplianceRule) -> ComplianceSuggestion? {
        notes.complianceSuggestions.first { $0.rule == rule && $0.isOpen(in: report) }
    }
}

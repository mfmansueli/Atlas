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

    static func load(_ app: StoreApp, in context: MCPToolContext) async throws -> MCPComplianceState {
        let services = context.workspace.services.appInformation
        let content = try await services.content(for: app, versionID: nil)
        let compliance = try await services.compliance(for: app)
        let builder = AppInformationChangeBuilder(appID: app.id, ids: content.ids, versionString: content.version?.versionString)
        let changes = context.workspace.changes.changes(for: app.id, section: .appInformation)
        let notes = services.notes.notes(for: app.id)
        let report = ComplianceReport(
            appName: app.name,
            content: compliance,
            general: builder.general(content.general, with: changes),
            ageRating: builder.ageRating(content.ageRating, with: changes).answers,
            answers: notes.compliance,
            stopsSellingInChina: builder.stopsSelling(in: ComplianceRegion.chinaMainland, with: changes)
        )
        let prepared = notes.compliance.traderDetails ?? TraderDetails(
            name: context.workspace.teamName,
            phone: content.review.phone,
            email: content.review.email
        )
        return MCPComplianceState(app: app, report: report, notes: notes, preparedTraderDetails: prepared)
    }

    /// The open suggestion for `rule`, if an assistant left one.
    func suggestion(for rule: ComplianceRule) -> ComplianceSuggestion? {
        notes.complianceSuggestions.first { $0.rule == rule && $0.isOpen(in: report) }
    }
}

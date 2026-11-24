//
//  MCPReleaseReadiness.swift
//  Atlas
//

import Foundation

/// What the Submit sheet checks before a version goes to App Review, read
/// for the release tools: What's New in every language (written, accepted
/// and not pushed, suggested or missing), the In-App Events that could go
/// with it, the encryption answer kept in Export Compliance, and the
/// changes waiting in Review & Push.
@MainActor
struct MCPReleaseReadiness {
    var whatsNew: [WhatsNewRow] = []
    /// Drafts (and events ready for review or rejected) that haven't ended.
    var offeredEvents: [InAppEvent] = []
    /// Nil when the events couldn't be read.
    var eventsError: String?
    var savedEncryption: EncryptionAnswer?
    var pendingChanges = 0

    static func load(for status: ReleaseStatus, app: StoreApp, in context: MCPToolContext, now: Date) async -> MCPReleaseReadiness {
        let workspace = context.workspace
        let services = workspace.services
        var readiness = MCPReleaseReadiness()
        let content = try? await services.storePage.content(for: app, versionID: status.version.id)
        readiness.whatsNew = WhatsNewRow.rows(
            for: content, appID: app.id, queue: workspace.changes, suggestions: workspace.suggestions ?? FieldSuggestionStore()
        )
        do {
            readiness.offeredEvents = try await ReleaseViewModel.offeredEvents(in: services.inAppEvents.events(for: app), now: now)
        } catch {
            readiness.eventsError = error.localizedDescription
        }
        readiness.savedEncryption = EncryptionAnswer(services.appInformation.notes.notes(for: app.id).exportAnswers)
        readiness.pendingChanges = workspace.changes.count(for: app.id)
        return readiness
    }

    /// The answer `build` carries, else the one kept in Export Compliance.
    func encryption(for build: ReleaseBuild?) -> EncryptionAnswer? {
        EncryptionAnswer.known(saved: savedEncryption, build: build)
    }

    /// Languages with no What's New and nothing suggested.
    var missingWhatsNew: [WhatsNewRow] {
        whatsNew.filter { $0.state == .missing }
    }

    /// Languages whose What's New waits as a suggestion for the person.
    var suggestedWhatsNew: [WhatsNewRow] {
        whatsNew.filter { if case .suggested = $0.state { true } else { false } }
    }

    /// What stops Submit with the sheet's starting choices, in the sheet's
    /// words: "choose a build", "add What’s New in Italian"…
    func blockers(for status: ReleaseStatus) -> [String] {
        var blockers: [String] = []
        let build = ReleaseViewModel.defaultBuildID(in: status).flatMap { id in status.builds.first { $0.id == id } }
        if build == nil {
            blockers.append(String(localized: "upload a build from Xcode (none is ready yet)"))
        }
        let missing = whatsNew.filter(\.isMissing)
        if !missing.isEmpty {
            blockers.append(String(localized: "add What’s New in \(missing.map(\.locale.name).formatted(.list(type: .and)))"))
        }
        if encryption(for: build) == nil { blockers.append(String(localized: "answer the encryption question")) }
        if !status.isReviewInformationComplete { blockers.append(String(localized: "complete the App Review information")) }
        return blockers
    }
}

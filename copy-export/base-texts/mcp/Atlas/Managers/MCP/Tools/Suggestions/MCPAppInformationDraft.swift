//
//  MCPAppInformationDraft.swift
//  Atlas
//

import Foundation

/// One app's General, Age Rating, Accessibility, App Privacy URLs and App
/// Review values as an assistant sees them: App Store Connect's for the newest editable
/// version (else the live one), with everything already queued laid on
/// top, as App Information shows them. The demo password is never read.
@MainActor
struct MCPAppInformationDraft {
    let app: StoreApp
    let slots: AppInformationSlotValues

    var content: AppInformationContent { slots.content }
    var builder: AppInformationChangeBuilder { slots.builder }
    var general: GeneralValues { slots.general }
    /// A new version waiting in Review & Push whose App Review details and
    /// version fields these are: what's written is queued tied to it.
    var queuedVersion: QueuedAppVersion?

    /// Accessibility is read only when `includesAccessibility`, and App
    /// Privacy's URLs only when `includesPrivacyURLs`; what can't be read
    /// can't take suggestions.
    /// The version being prepared, or with `version` a new one waiting in
    /// Review & Push (`MCPVersionTarget`).
    static func load(
        app identifier: String,
        version: String? = nil,
        in workspace: MCPWorkspace,
        includesAccessibility: Bool = true,
        includesPrivacyURLs: Bool = false
    ) async throws -> MCPAppInformationDraft {
        let app = try await workspace.app(matching: identifier)
        let services = workspace.services.appInformation
        var content: AppInformationContent
        var queued: QueuedAppVersion?
        do {
            content = try await services.content(for: app, versionID: nil)
            queued = try MCPVersionTarget.queued(
                version, app: app, shown: content.version?.versionString, versions: content.versions, in: workspace
            )
            if let queued {
                if let base = queued.baseVersionID(among: content.versions), base != content.version?.id {
                    content = try await services.content(for: app, versionID: base)
                }
                content = queued.appInformationContent(from: content)
            }
        } catch let error as MCPToolError {
            throw error
        } catch {
            throw MCPToolError.unavailable(String(localized: "Couldn’t read \(app.name)’s app information: \(error.localizedDescription)"))
        }
        let accessibility = includesAccessibility ? try? await services.accessibility(for: app) : nil
        var privacyURLs = includesPrivacyURLs ? try? await services.privacyURLs(for: app) : nil
        if let queued, let base = privacyURLs { privacyURLs = queued.privacyURLsContent(from: base) }
        let builder = AppInformationChangeBuilder(appID: app.id, ids: content.ids, versionString: content.version?.versionString)
        var draft = MCPAppInformationDraft(
            app: app,
            slots: AppInformationSlotValues(content: content, accessibility: accessibility, builder: builder, changes: [], privacyURLs: privacyURLs)
        )
        draft.queuedVersion = queued
        return draft.with(changes: draft.queuedChanges(in: workspace.changes))
    }

    /// The same values with `changes` queued instead.
    func with(changes: [PendingChange]) -> MCPAppInformationDraft {
        var draft = MCPAppInformationDraft(
            app: app,
            slots: AppInformationSlotValues(
                content: content, accessibility: slots.accessibility, builder: builder, changes: changes, privacyURLs: slots.privacyURLs
            )
        )
        draft.queuedVersion = queuedVersion
        return draft
    }

    /// What's queued for these values: App Information's changes, and a
    /// new version's own, which wait with it under its row in Review &
    /// Push (read here as App Information's again).
    func queuedChanges(in queue: ChangeQueue) -> [PendingChange] {
        let information = queue.changes(for: app.id, section: .appInformation)
        guard let queuedVersion else { return information }
        return information + queue.changes(for: app.id).filter(queuedVersion.isTied).map { change in
            var change = change
            change.section = .appInformation
            return change
        }
    }

    /// `change` as it's queued: tied to the new version it writes into.
    func queueable(_ change: PendingChange) -> PendingChange {
        queuedVersion?.tie(change) ?? change
    }

    /// The field's value as shown, as stored (categories by id).
    func value(_ field: AppInformationSuggestionField) -> String {
        slots.value(.field(field))
    }

    /// App Store Connect's value, before anything queued.
    func liveValue(_ field: AppInformationSuggestionField) -> String {
        slots.liveValue(.field(field))
    }

    /// Version-level fields of a version in review or live.
    func isLocked(_ field: AppInformationSuggestionField) -> Bool {
        field.isVersionLevel && !content.isVersionEditable
    }

    var versionJSON: JSONValue {
        guard let version = content.version else { return .null }
        guard queuedVersion == nil else { return MCPListingDraft.queuedVersionJSON(version.versionString) }
        return [
            "versionString": .string(version.versionString),
            "state": .string(version.state.title),
            "editable": .bool(version.isEditable),
        ]
    }

    /// "Lumen Journal · App Review · Notes".
    func target(_ field: AppInformationSuggestionField?) -> String {
        [app.name, field?.page.title, field?.title].compactMap(\.self).joined(separator: " · ")
    }
}

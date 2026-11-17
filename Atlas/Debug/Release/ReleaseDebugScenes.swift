//
//  ReleaseDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The DEBUG scenes of Submit for Review and release
/// (`-AtlasDebugScene <id>`), one per state on the design's board
/// 39, all on Overview with Lumen Journal 1.4. "Today" is Nov 16, 2026.
///
/// - `rel-prep`: before submitting: what goes to App Review and what's
///   missing (What's New in Italian, suggested).
/// - `rel-sheet`: the Submit sheet; `rel-sheet-push`: with four changes
///   not pushed yet, released right after approval; `rel-sheet-ok`: the
///   Italian What's New accepted and encryption answered, ready to submit.
/// - `rel-wait`, `rel-review`, `rel-pending` (approved, waiting for you),
///   `rel-phased` (day 3 of 7), `rel-paused`, `rel-rejected`, `rel-live`.
/// - `rel-refused`: App Store Connect refuses every write.
enum ReleaseDebugScenes {
    typealias AppIDs = DebugFixtures.AppID
    typealias Data = DebugReleaseData

    static let ids = [
        "rel-prep", "rel-sheet", "rel-sheet-push", "rel-sheet-ok", "rel-wait", "rel-review", "rel-pending", "rel-phased", "rel-paused",
        "rel-rejected", "rel-live", "rel-refused",
    ]

    /// The scenes that are the version card in one phase.
    private static let phases: [String: DebugReleasePhase] = [
        "rel-prep": .prepare, "rel-wait": .waiting, "rel-review": .review, "rel-pending": .pending, "rel-phased": .phased,
        "rel-paused": .paused, "rel-rejected": .rejected, "rel-live": .live, "rel-refused": .waiting,
    ]

    @MainActor
    static func view(for id: String) -> AnyView? {
        if let phase = phases[id] { return scene(phase, refusesWrites: id == "rel-refused") }
        switch id {
        case "rel-sheet":
            return scene(.prepare, launch: ReleaseDebugLaunch(opensSubmit: true))
        case "rel-sheet-push":
            return scene(.prepare, launch: ReleaseDebugLaunch(opensSubmit: true, timing: .afterApproval), pendingChanges: acceptedChanges)
        case "rel-sheet-ok":
            let launch = ReleaseDebugLaunch(opensSubmit: true, encryption: .exempt)
            return scene(.prepare, launch: launch, pendingChanges: [acceptedWhatsNew], isWhatsNewAccepted: true)
        default:
            return nil
        }
    }

    /// The Italian What's New, accepted from Claude Code and not pushed.
    static var acceptedWhatsNew: PendingChange {
        let content = DebugStorePageContent.lumen(versionID: nil)
        let builder = ListingChangeBuilder(appID: AppIDs.lumen, ids: content.ids, versionString: Data.versionString)
        return PendingChange(
            id: builder.changeID(for: ListingFieldKey(Data.missingLocale, .whatsNew)), appID: AppIDs.lumen, section: .storePage,
            group: "Store Page · Version \(Data.versionString)", title: "\(Data.missingLocale.name) · What’s New", flagRegion: Data.missingLocale.regionCode,
            oldValue: "", newValue: Data.suggestedWhatsNew, source: .assistant(client: DebugReviewsData.client), requests: []
        )
    }

    /// Four changes accepted in Store Page, not pushed yet.
    static var acceptedChanges: [PendingChange] {
        [
            change("en-US.keywords", "English (U.S.) · Keywords", region: "US", value: "journal,diary,mood,gratitude,reflection"),
            change("en-US.promotionalText", "English (U.S.) · Promotional Text", region: "US", value: "New: the Mood Calendar shows your month in color."),
            change("de-DE.promotionalText", "German · Promotional Text", region: "DE", value: "Neu: Der Stimmungskalender zeigt deinen Monat in Farbe."),
            change("de-DE.keywords", "German · Keywords", region: "DE", value: "tagebuch,stimmung,dankbarkeit,reflexion"),
        ]
    }

    private static func change(_ key: String, _ title: String, region: String, value: String) -> PendingChange {
        PendingChange(
            id: "storePage.\(AppIDs.lumen).debug.\(key)", appID: AppIDs.lumen, section: .storePage,
            group: "Store Page · Version \(Data.versionString)", title: title, flagRegion: region, oldValue: "", newValue: value, requests: []
        )
    }

    @MainActor
    private static func scene(
        _ phase: DebugReleasePhase,
        launch: ReleaseDebugLaunch = ReleaseDebugLaunch(),
        pendingChanges: [PendingChange] = [],
        isWhatsNewAccepted: Bool = false,
        refusesWrites: Bool = false
    ) -> AnyView {
        ReleaseDebugLaunch.pending = launch
        return AnyView(DebugMainScene(
            services: services(phase, encryption: launch.encryption, refusesWrites: refusesWrites), selectedAppID: AppIDs.lumen, section: .overview,
            pendingChanges: pendingChanges,
            suggestions: isWhatsNewAccepted ? FieldSuggestionStore() : Data.suggestions(), release: Data.store(phase)
        ))
    }

    /// Lumen 1.4 in `phase`, with What's New written everywhere but in
    /// Italian, and the encryption question open unless `encryption`
    /// answers it (the sample's Export Compliance has an answer).
    @MainActor
    static func services(_ phase: DebugReleasePhase, encryption: EncryptionAnswer? = nil, refusesWrites: Bool = false) -> WorkspaceServices {
        var services = WorkspaceServices.debug
        let notes = services.appInformation.notes
        var kept = notes.notes(for: AppIDs.lumen)
        kept.exportAnswers = encryption?.answers
        notes.setNotes(kept, for: AppIDs.lumen)
        services.release = DebugReleaseServices(state: DebugReleaseState(phase), refusesWrites: refusesWrites)
        var storePage = DebugStorePageServices()
        storePage.whatsNew = Data.whatsNew
        services.storePage = storePage
        return services
    }
}
#endif

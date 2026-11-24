//
//  NominationsDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The Nominations DEBUG scenes (`-AtlasDebugScene <id>`), board 70, on
/// Lumen on Nov 24, 2026.
///
/// - `ft-empty`; `ft-gallery` (Drafts → Submitted → Archived);
///   `ft-proposed` (Claude Code's Mood Calendar at the top of Drafts).
/// - `ft-new` (an empty draft); `ft-edit` (Lumen 1.4); `ft-suggest` (Atlas's
///   type and description); `ft-events`, `ft-links`, `ft-markets`
///   (countries "Some", markets first), `ft-multi` (with Quiet Timer),
///   `ft-soon` (starts in 9 days).
/// - `ft-queued` (after Add to Review & Push); `ft-cc-acc` (Claude Code's
///   nomination accepted); `ft-submit` and `ft-archive` (the sheets);
///   `ft-submitted` (read-only).
/// - `ft-err-role`, `ft-err-refused`, `ft-err-date`, `ft-offline`.
/// - `ft-rp`, `ft-rp-cc`: Review & Push with the nomination's rows;
///   `ft-ap`: the gallery, for the toolbar's Autopilot menu.
/// - `ft-gallery-s`, `ft-s`: the sidebar hidden, for 860 × 560.
enum NominationsDebugScenes {
    typealias Data = DebugNominationsData

    static let ids = [
        "ft-empty", "ft-gallery", "ft-proposed", "ft-new", "ft-edit", "ft-suggest", "ft-events", "ft-links", "ft-markets", "ft-multi",
        "ft-soon", "ft-queued", "ft-submit", "ft-submitted", "ft-archive", "ft-err-role", "ft-err-refused", "ft-err-date", "ft-offline",
        "ft-rp", "ft-ap", "ft-cc-acc", "ft-rp-cc", "ft-gallery-s", "ft-s",
    ]

    private static let draft = NominationsViewModel.Selection.nomination(Data.draftID)

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        if id.hasSuffix("-s") { NavigationDebugLaunch.hidesSidebar = true }
        switch id {
        case "ft-empty":
            return scene(services: DebugNominationsServices(nominations: []), archive: NominationsArchive())
        case "ft-gallery", "ft-ap", "ft-gallery-s":
            return scene()
        case "ft-proposed":
            return scene(archive: Data.archive(proposal: true))
        case "ft-new":
            return scene(NominationsDebugLaunch(opensNew: true))
        case "ft-edit", "ft-s", "ft-soon", "ft-events", "ft-links":
            return scene(NominationsDebugLaunch(selection: draft))
        case "ft-suggest":
            return scene(NominationsDebugLaunch(selection: draft) { $0.type = nil; $0.description = "" })
        case "ft-markets":
            return scene(NominationsDebugLaunch(selection: draft) { content in
                content.territories = ["USA", "GBR", "CAN", "AUS"]
                content.launchInSelectMarketsFirst = true
            })
        case "ft-multi":
            return scene(NominationsDebugLaunch(selection: draft) { $0.appIDs = [Data.lumen, Data.quiet] })
        case "ft-queued":
            return scene(NominationsDebugLaunch(selection: draft, addsToReviewPush: true))
        case "ft-submit":
            return scene(NominationsDebugLaunch(selection: draft, sheet: .submit(Data.draftID)))
        case "ft-submitted":
            return scene(NominationsDebugLaunch(selection: .nomination(Data.winterID)))
        case "ft-archive":
            return scene(NominationsDebugLaunch(selection: .nomination(Data.winterID), sheet: .archive(Data.winterID)))
        case "ft-err-role":
            let forbidden = AppStoreConnectError.forbidden(detail: "The key’s role can’t read nominations.")
            return scene(NominationsDebugLaunch(selection: draft), services: DebugNominationsServices(error: forbidden))
        case "ft-err-refused":
            var archive = Data.archive()
            archive.drafts[0].content.description += " Watch the film: lumen.app/weekly"
            archive.refusals[Data.draftID] = Data.refusal
            return scene(NominationsDebugLaunch(selection: draft, showsRefusalDetails: true), archive: archive)
        case "ft-err-date":
            return scene(NominationsDebugLaunch(selection: draft) { $0.publishStart = Data.day(2026, 11, 20) })
        case "ft-offline":
            return scene(services: DebugNominationsServices(error: URLError(.notConnectedToInternet)))
        case "ft-rp":
            return scene(pendingChanges: draftRows(submit: true), presentedSheet: .review)
        case "ft-cc-acc":
            return scene(NominationsDebugLaunch(selection: .proposal(Data.proposalID)), archive: Data.archive(proposal: true), accepts: true)
        case "ft-rp-cc":
            return scene(archive: Data.archive(proposal: true), accepts: true, presentedSheet: .review)
        default:
            return nil
        }
    }

    /// Lumen 1.4's Create row, and its Submit row.
    @MainActor
    private static func draftRows(submit: Bool) -> [PendingChange] {
        let builder = NominationChangeBuilder(appID: Data.lumen)
        var rows = [(try? builder.create(Data.draft, now: Data.now))].compactMap(\.self)
        if submit, let row = try? builder.submit(Data.draft, now: Data.now) { rows.append(row) }
        return rows
    }

    @MainActor
    private static func scene(
        _ launch: NominationsDebugLaunch = NominationsDebugLaunch(),
        services nominations: DebugNominationsServices = DebugNominationsServices(),
        archive: NominationsArchive = Data.archive(),
        accepts: Bool = false,
        pendingChanges: [PendingChange] = [],
        presentedSheet: WorkspaceSheet? = nil
    ) -> AnyView {
        var services = WorkspaceServices.debug
        services.nominations = nominations
        let store = NominationsStore.shared
        store.load(archive, for: Data.lumen)
        var changes = pendingChanges
        if accepts {
            // Claude Code's nomination, accepted: a draft marked as its,
            // with its Create row in Review & Push.
            let proposal = Data.proposal
            var accepted = Nomination(id: "local-debug-mood", content: proposal.content, createdDate: Data.now, suggestedBy: proposal.client)
            accepted.content.appIDs = [Data.lumen]
            var settled = archive
            settled.proposals = []
            settled.drafts.append(accepted)
            store.load(settled, for: Data.lumen)
            if let row = try? NominationChangeBuilder(appID: Data.lumen).create(accepted, source: .assistant(client: proposal.client), now: Data.now) {
                changes.append(row)
            }
            var launch = launch
            launch.selection = presentedSheet == nil ? .nomination(accepted.id) : nil
            NominationsDebugLaunch.pending = launch
        } else {
            NominationsDebugLaunch.pending = launch
        }
        return AnyView(DebugMainScene(
            services: services, selectedAppID: Data.lumen, section: .nominations, pendingChanges: changes, presentedSheet: presentedSheet
        ))
    }
}
#endif

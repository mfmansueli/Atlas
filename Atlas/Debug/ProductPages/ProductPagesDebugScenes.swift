//
//  ProductPagesDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The Custom Product Pages DEBUG scenes (`-AtlasDebugScene <id>`), boards
/// 50, 51, 53, 54 and 55, on Lumen Journal's sample pages:
///
/// - `cp`: the list with 2 suggested pages; `cp-sug` with one opened,
///   `cp-nosug` without; `cp-empty`, `cp-limit` (70 of 70), `cp-loading`,
///   `cp-offline`, `cp-norole` (a key that can't change pages).
/// - `cp-new`, `cp-new-copy`: the New Page sheet.
/// - `cp-edit` (Private diary, English), `cp-edit-de` (a suggestion),
///   `cp-edit-ar` (right to left), `cp-edit-fr` (nothing of its own),
///   `cp-edit-ipad`, `cp-edit-refused` (a text Atlas stopped),
///   `cp-edit-deeplink` (`lumen:/lock`), `cp-edit-noversion` (no approved
///   version, so no keywords), `cp-kwmove` (a keyword on another page),
///   `cp-edit-brief` (an accepted suggestion's brief under the screenshots).
/// - `cp-submit` (Private diary pushed), `cp-waiting`, `cp-inreview`,
///   `cp-approved` (Prompts), `cp-hidden` (Therapists), `cp-rejected`
///   (Year in review), `cp-liveedit` (Prompts, version 2 with 3 changes),
///   `cp-submit-brief` (pushed with a brief and no screenshots of its own).
/// - `cp-hide`, `cp-delete`, `cp-discard`: the confirmations.
/// - `cp-s`, `cp-edit-s`, `cp-edit-ar-s`: the sidebar hidden, for 860 × 560.
/// - `cp-overview`: the Overview's card; `cp-analytics`: Analytics' Product
///   Page breakdown with Open Page.
/// - Board 52, Make Screenshots for This Page on Private diary:
///   `cp-shots-planning` (Claude Code planning), `cp-shots-plan`,
///   `cp-shots-run` (2 made), `cp-shots-result`, `cp-shots-queued` (the
///   set in Review & Push, in the editor); `cp-shots-plan-s` at 860 × 560;
///   `cp-shots-none`: Lumen without a screenshot template, so the sheet
///   says so and opens Screenshots.
/// - Choose Files…: `cp-files` (two iPhone screenshots queued for Private
///   diary), `cp-files-wrong` (one of them 1170 × 2532, so nothing is
///   queued and the alert says why).
enum ProductPagesDebugScenes {
    typealias Data = DebugProductPagesData
    typealias PageID = DebugProductPagesData.PageID
    typealias Launch = ProductPagesDebugLaunch

    static let ids = [
        "cp", "cp-sug", "cp-nosug", "cp-empty", "cp-limit", "cp-loading", "cp-offline", "cp-norole", "cp-new", "cp-new-copy",
        "cp-edit", "cp-edit-de", "cp-edit-ar", "cp-edit-fr", "cp-edit-ipad", "cp-edit-refused", "cp-edit-deeplink",
        "cp-edit-noversion", "cp-kwmove", "cp-submit", "cp-waiting", "cp-inreview", "cp-approved", "cp-hidden", "cp-rejected",
        "cp-liveedit", "cp-hide", "cp-delete", "cp-discard", "cp-s", "cp-edit-s", "cp-edit-ar-s", "cp-overview", "cp-analytics",
        "cp-edit-brief", "cp-submit-brief", "cp-shots-planning", "cp-shots-plan", "cp-shots-run", "cp-shots-result",
        "cp-shots-queued", "cp-shots-plan-s", "cp-shots-none", "cp-files", "cp-files-wrong",
    ]

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        if id.hasSuffix("-s") { NavigationDebugLaunch.hidesSidebar = true }
        if id == "cp-shots-none" {
            return scene(Launch(pageID: PageID.privateDiary), screenshots: DebugScreenshotsServices(scenario: .noTemplate))
        }
        if let launch = launches[id] { return scene(launch) }
        return stateScene(id) ?? editorScene(id)
    }

    /// Scenes that are a launch over the sample pages.
    @MainActor
    private static var launches: [String: Launch] {
        let diary = PageID.privateDiary
        return [
            "cp": Launch(),
            "cp-sug": Launch(expandedSuggestionID: "weekly"),
            "cp-new": Launch(opensNewPage: true),
            "cp-new-copy": Launch(
                opensNewPage: true,
                newPage: NewProductPage(name: "Evening prompts", start: .copy(pageID: PageID.prompts, name: "Prompts"), locales: ["en-US"])
            ),
            "cp-offline": Launch(failure: "The Internet connection appears to be offline."),
            "cp-edit": Launch(pageID: diary),
            "cp-edit-de": Launch(pageID: diary, locale: "de-DE"),
            "cp-edit-ar": Launch(pageID: diary, locale: "ar-SA"),
            "cp-edit-fr": Launch(pageID: diary, locale: "fr-FR"),
            "cp-edit-ipad": Launch(pageID: diary, device: .iPad),
            "cp-kwmove": Launch(
                pageID: diary,
                confirmation: .moveKeyword("journal", locale: "en-US", fromPageID: PageID.prompts, fromName: "Prompts")
            ),
            "cp-submit": Launch(pageID: PageID.privateDiaryPushed, pushedPrivateDiary: .prepareForSubmission, opensSubmit: true),
            "cp-waiting": Launch(pageID: PageID.privateDiaryPushed, pushedPrivateDiary: .waitingForReview),
            "cp-inreview": Launch(pageID: PageID.privateDiaryPushed, pushedPrivateDiary: .inReview),
            "cp-approved": Launch(pageID: PageID.prompts),
            "cp-hidden": Launch(pageID: PageID.therapists),
            "cp-rejected": Launch(pageID: PageID.year),
            "cp-liveedit": Launch(pageID: PageID.prompts, editsApproved: liveEdits),
            "cp-hide": Launch(pageID: PageID.prompts, confirmation: .hide(pageID: PageID.prompts)),
            "cp-delete": Launch(pageID: PageID.year, confirmation: .delete(pageID: PageID.year)),
            "cp-discard": Launch(pageID: PageID.prompts, confirmation: .discard(pageID: PageID.prompts), editsApproved: liveEdits),
            "cp-s": Launch(),
            "cp-edit-s": Launch(pageID: diary),
            "cp-edit-ar-s": Launch(pageID: diary, locale: "ar-SA"),
            "cp-shots-planning": Launch(pageID: diary, pageShots: .planning),
            "cp-shots-plan": Launch(pageID: diary, pageShots: .plan),
            "cp-shots-run": Launch(pageID: diary, pageShots: .making),
            "cp-shots-result": Launch(pageID: diary, pageShots: .result),
            "cp-shots-queued": Launch(pageID: diary, pageShots: .used),
            "cp-shots-plan-s": Launch(pageID: diary, pageShots: .plan),
            "cp-files": Launch(pageID: diary, chosenSizes: [PixelSize(width: 1320, height: 2868), PixelSize(width: 1320, height: 2868)]),
            "cp-files-wrong": Launch(pageID: diary, chosenSizes: [PixelSize(width: 1320, height: 2868), PixelSize(width: 1170, height: 2532)]),
        ]
    }

    /// The list in a state of its own.
    @MainActor
    private static func stateScene(_ id: String) -> AnyView? {
        switch id {
        case "cp-nosug":
            scene(store: Data.store(Data.archive(suggestions: false)))
        case "cp-empty":
            scene(services: DebugProductPagesServices(isEmpty: true), store: Data.store(Data.archive(suggestions: false, drafts: false)), pending: [])
        case "cp-limit":
            scene(services: DebugProductPagesServices(isAtLimit: true), store: Data.store(Data.archive(suggestions: false)))
        case "cp-loading":
            scene(services: DebugProductPagesServices(neverLoads: true))
        case "cp-norole":
            scene(store: noRoleStore())
        case "cp-overview":
            overview()
        case "cp-analytics":
            AnalyticsDebugScenes.view(for: "an-bd-ppo")
        default:
            nil
        }
    }

    /// The editor on a page made a particular way.
    @MainActor
    private static func editorScene(_ id: String) -> AnyView? {
        switch id {
        case "cp-edit-refused":
            var archive = Data.archive()
            archive.textSuggestions.append(Data.refusedSuggestion)
            return scene(Launch(pageID: PageID.privateDiary), store: Data.store(archive))
        case "cp-edit-deeplink":
            var draft = Data.privateDiary
            draft.deepLink = "lumen:/lock"
            var archive = Data.archive()
            archive.drafts = [draft]
            return scene(Launch(pageID: PageID.privateDiary), store: Data.store(archive), pending: Data.pendingChanges(draft))
        case "cp-edit-noversion":
            return scene(Launch(pageID: PageID.privateDiary), services: DebugProductPagesServices(hasNoApprovedVersion: true))
        case "cp-edit-brief":
            return scene(Launch(pageID: PageID.privateDiary), store: briefStore())
        case "cp-submit-brief":
            let launch = Launch(pageID: PageID.privateDiaryPushed, pushedPrivateDiary: .prepareForSubmission, opensSubmit: true)
            return scene(launch, store: briefStore())
        default:
            return nil
        }
    }

    /// The sample pages with the brief Claude Code's “Private diary” left.
    @MainActor
    private static func briefStore() -> ProductPagesStore {
        let store = Data.store()
        let brief = ProductPageBrief(
            audience: "People who want a diary nobody else can open",
            screens: "Lock (“Locked with Face ID”), then Write (“Only on your devices”), then Search",
            source: "Claude Code"
        )
        store.saveBrief(brief, pageName: "Private diary", for: Data.appID)
        return store
    }

    /// Prompts' version 2: a new English text, a keyword more and a new
    /// deep link.
    @MainActor
    private static var liveEdits: [PendingChange] {
        let builder = ProductPageChangeBuilder(appID: Data.appID)
        guard let prompts = Data.pages.first(where: { $0.id == PageID.prompts }) else { return [] }
        return [
            builder.textChange(
                "A new prompt every evening, and a question to end the week. Start with one line.", locale: "en-US", of: prompts, source: .you
            ),
            builder.keywordsChange(["journal", "prompts", "daily", "reflection"], locale: "en-US", of: prompts, source: .you),
            builder.deepLinkChange("https://lumen.app/prompts/week", of: prompts, source: .you),
        ].compactMap(\.self)
    }

    @MainActor
    private static func noRoleStore() -> ProductPagesStore {
        let store = Data.store()
        store.setKeyCannotChange(true, for: Data.appID)
        return store
    }

    @MainActor
    private static func overview() -> AnyView {
        var services = WorkspaceServices.debug
        services.productPages = DebugProductPagesServices()
        return AnyView(DebugMainScene(
            services: services, section: .overview, pendingChanges: DebugWorkspace.pendingChanges + Data.pendingChanges,
            analytics: Data.analytics(), prefetchesSections: true
        ))
    }

    @MainActor
    private static func scene(
        _ launch: Launch = Launch(),
        services pages: DebugProductPagesServices = DebugProductPagesServices(),
        store: ProductPagesStore? = nil,
        pending: [PendingChange]? = nil,
        screenshots: (any ScreenshotsServices)? = nil
    ) -> AnyView {
        var services = WorkspaceServices.debug
        services.productPages = pages
        if let screenshots {
            var storePage = DebugStorePageServices()
            storePage.screenshots = screenshots
            services.storePage = storePage
        }
        Launch.pending = launch
        return AnyView(DebugMainScene(
            services: services, section: .productPages,
            pendingChanges: DebugWorkspace.pendingChanges + (pending ?? Data.pendingChanges),
            analytics: Data.analytics(), productPages: store ?? Data.store()
        ))
    }
}
#endif

//
//  AppInformationViewModel.swift
//  Atlas
//

import Foundation
import Observation

/// The App Information section's state: App Store Connect's values for the
/// app and the chosen version, with every pending change laid on top, and
/// the edits that queue new ones.
///
/// The `ChangeQueue` is where edits live. Every edit builds the field's
/// `PendingChange` (`AppInformationChangeBuilder`) and upserts it, or
/// discards it when the value is back at App Store Connect's. The pages
/// read their values through the builder from the content plus the queue,
/// so discarding a change in Review & Push reverts the page, and queued
/// values survive navigation and relaunch. Each page's edits are in
/// `AppInformationViewModel+<Page>.swift`.
@MainActor
@Observable
final class AppInformationViewModel {
    let app: StoreApp
    let services: any AppInformationServices
    let queue: ChangeQueue
    /// Field suggestions for General and App Review, from the built-in
    /// checks and assistants.
    let suggestions: FieldSuggestionStore
    private let summaries: AppSummaryStore?
    private let push: PushController?

    // MARK: - Loaded state

    private(set) var content: AppInformationContent?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var accessibility: LoadState<AccessibilityContent> = .idle
    /// The status, Apple's code and the request of a failed accessibility
    /// load.
    private(set) var accessibilityErrorLine: String?
    /// Where the app is sold and what Apple finds missing there, for App
    /// Compliance. It loads on its own, like Accessibility.
    private(set) var compliance: LoadState<ComplianceContent> = .idle
    /// The status, Apple's code and the request of a failed compliance
    /// load.
    private(set) var complianceErrorLine: String?
    /// What's kept on this Mac: the override's reason, export answers,
    /// assistants' evidence. Read from the store every time, so evidence an
    /// assistant sends over MCP shows up, and an edit here never writes back
    /// an older copy over it.
    var notes: AppInformationNotes {
        get { services.notes.notes(for: app.id) }
        set { services.notes.setNotes(newValue, for: app.id) }
    }

    /// The App Privacy page.
    let privacy: AppPrivacyViewModel

    // MARK: - Navigation

    var page: AppInformationPage = .general
    /// The accessibility editor sheet, while it's open.
    var editor: AccessibilityEditorDraft?
    /// The editor's line after Copy from iPhone.
    var editorMessage: String?
    /// Said after an action, e.g. "Saved. It’s waiting in Review & Push…".
    var toast: String?
    /// The question whose evidence popover is open.
    var evidenceQuestion: AgeRatingQuestion?
    var showsExportEvidence = false
    /// App Compliance: the trader details are being edited.
    var isEditingTrader = false
    /// The team's name as its certificates give it, for the prepared
    /// trader details; nil when it isn't known.
    var sellerName: String?
    var isPasswordVisible = false

    // MARK: - Suggestions

    /// The suggestion bar's source filter.
    var suggestionFilter: SuggestionSourceFilter = .all
    /// "Only fields with suggestions or changes".
    var showsOnlySuggestedFields = false
    /// "Not Now" on the card offering to set up an assistant.
    var hidesAssistantCTA = false
    /// The Assistant button's Ask for Suggestions…: the bar asks once shown.
    var requestsAsk = false
    /// The field "Use and Edit" filled, for the page to focus.
    var focusRequest: AppInformationSuggestionField?
    /// The device Accessibility's suggestions are shown for.
    var accessibilitySuggestionFamily: DeviceFamily = .iPhone
    /// What a suggestion action did, with Undo. `toast` stays the page's
    /// plain message.
    var suggestionToast: ToastMessage?
    /// "Accept suggestions on every App Information page".
    var isAcceptAllPresented = false
    /// What the toast's Undo puts back.
    var suggestionUndo: AppInformationSuggestionUndo?
    /// The window's, so Accept All is one step of Edit → Undo.
    weak var undoManager: UndoManager?
    /// The version before the shown one's App Review details, for the
    /// built-in contact suggestions.
    var previousReview: AppInformationBuiltInSuggestions.PreviousReview?

    private var selectedVersionID: String?

    init(
        app: StoreApp,
        services: any AppInformationServices,
        queue: ChangeQueue,
        suggestions: FieldSuggestionStore = FieldSuggestionStore(),
        summaries: AppSummaryStore? = nil,
        push: PushController? = nil
    ) {
        self.app = app
        self.services = services
        self.queue = queue
        self.suggestions = suggestions
        self.summaries = summaries
        self.push = push
        privacy = AppPrivacyViewModel(app: app, services: services, queue: queue)
        privacy.owner = self
    }

    // MARK: - Loading

    /// Loads the pages, then the accessibility declarations, then where
    /// the app is sold for App Compliance, then the privacy URLs if App
    /// Privacy showed them.
    func load() async {
        await loadContent()
        await loadAccessibility()
        await loadCompliance()
        await privacy.reloadURLsIfLoaded()
    }

    /// Fetches General, Age Rating, App Review and Export Compliance for the
    /// chosen version. A failure keeps what was shown and says why.
    func loadContent() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let previous = content
            content = try await services.content(for: app, versionID: selectedVersionID)
            errorMessage = nil
            refreshSummaryIfNeeded(after: previous)
            if let content { previousReview = await services.previousReview(for: app, content: content) }
            refreshSuggestions()
        } catch {
            errorMessage = AppInformationErrorReporter.report(error, to: push)
        }
    }

    /// Fetches the accessibility declarations; Try Again calls it too.
    func loadAccessibility() async {
        if accessibility.value == nil { accessibility = .loading }
        do {
            accessibility = try await .loaded(services.accessibility(for: app))
            accessibilityErrorLine = nil
            refreshSuggestions()
        } catch {
            accessibility = .failed(String(localized: "Couldn’t load accessibility declarations."))
            accessibilityErrorLine = AppInformationErrorReporter.requestLine(for: error, request: "/v1/apps/\(app.id)/accessibilityDeclarations")
        }
    }

    /// Fetches the app's countries and regions with Apple's statuses; Try
    /// Again calls it too. What was read stays when a reload fails.
    func loadCompliance() async {
        if compliance.value == nil { compliance = .loading }
        do {
            compliance = try await .loaded(services.compliance(for: app))
            complianceErrorLine = nil
        } catch {
            complianceErrorLine = AppInformationErrorReporter.requestLine(for: error, request: "/v1/apps/\(app.id)/appAvailabilityV2")
            if compliance.value == nil { compliance = .failed(String(localized: "Couldn’t read where the app is sold.")) }
        }
    }

    /// Whether the app sells subscriptions or in-app purchases, from the
    /// overview's numbers; nil until they have loaded.
    var sellsInApp: Bool? {
        summaries?.pricing[app.id]?.value.map { $0.subscriptionCount + $0.inAppPurchaseCount > 0 }
    }

    /// Picks another version in the version menu.
    func selectVersion(_ id: StorePageVersion.ID) async {
        guard id != content?.version?.id else { return }
        selectedVersionID = id
        await loadContent()
    }

    var isLoaded: Bool { content != nil }

    // MARK: - Queue

    /// The builder for this app and the shown version. Accessibility only
    /// needs the app, so it works before the rest has loaded.
    var builder: AppInformationChangeBuilder {
        AppInformationChangeBuilder(
            appID: app.id,
            ids: content?.ids ?? AppInformationResourceIDs(appID: app.id, appInfoID: ""),
            versionString: content?.version?.versionString
        )
    }

    /// This app's queued App Information changes.
    var changes: [PendingChange] {
        queue.changes(for: app.id, section: .appInformation)
    }

    /// Queues `change`, or discards the change at `id` when there's
    /// nothing to push any more. Your edit on the page replaces an
    /// assistant's proposal for the same field, and keeps a publish switch
    /// you already flipped in review.
    func apply(_ change: PendingChange?, id: String) {
        guard var change else {
            queue.discard(id: id)
            refreshSuggestions()
            return
        }
        if let old = queue.change(id: change.id) {
            change.createdAt = old.createdAt
            if change.newValue == old.newValue { change.remoteConflict = old.remoteConflict }
            if let wasOn = old.option?.isOn, change.option?.isEnabled == true { change.option?.isOn = wasOn }
            guard change != old else { return }
            if old.source.isAssistant, !change.source.isAssistant { queue.discard(id: old.id) }
        }
        queue.upsert(change)
        refreshSuggestions()
    }

    /// Tells the overview and sidebar when a reload brought a different
    /// rating or App Review state than they show.
    private func refreshSummaryIfNeeded(after previous: AppInformationContent?) {
        guard let previous, let content, let summaries else { return }
        let changed = previous.ageRating.currentRating != content.ageRating.currentRating
            || previous.review.isComplete != content.review.isComplete
        guard changed else { return }
        summaries.invalidate(app.id)
        Task { [app] in await summaries.load(app) }
    }
}

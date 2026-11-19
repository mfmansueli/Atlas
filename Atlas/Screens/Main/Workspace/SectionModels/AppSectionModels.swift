//
//  AppSectionModels.swift
//  Atlas
//

import Foundation

/// One app's section models, kept while the person moves between the
/// sections, so coming back to one shows what it had instead of reading
/// App Store Connect again. Each section stamps its model when a read
/// finishes and reads again only once the stamp is stale. The sections
/// the person isn't looking at are read ahead in the background
/// (`SectionPrefetcher`); one opened while its read ahead runs waits for
/// it instead of starting its own.
@MainActor
final class AppSectionModels {
    var storePage: StorePageViewModel?
    var appInformation: AppInformationViewModel?
    var pricing: PricingViewModel?
    var retention: RetentionModel?
    var screenshots: ScreenshotsSectionModel?
    /// Analytics' view, period and selection, so Back to Analytics lands
    /// where the person left.
    var analytics: AnalyticsViewModel?
    /// Reviews' filter and the replies being written.
    var reviews: ReviewsViewModel?
    /// The version on its way to the App Store: the Overview's card, the
    /// Submit sheet and the sidebar's footer.
    var release: ReleaseViewModel?
    /// In-App Events: the selected event and language.
    var events: InAppEventsViewModel?
    /// Product Pages: the selected page and the drafts on it.
    var productPages: ProductPagesViewModel?
    /// The page Overview's App Store preview draws.
    var overviewContent: StorePageContent?

    private var stamps: [AppWorkspaceSection: SectionLoadStamp] = [:]
    /// The sections being read ahead.
    private var warming: [AppWorkspaceSection: Task<Void, Never>] = [:]
    private let maximumAge: TimeInterval
    private let now: () -> Date

    init(maximumAge: TimeInterval, now: @escaping () -> Date) {
        self.maximumAge = maximumAge
        self.now = now
    }

    /// True when `section` has to read App Store Connect: it never
    /// finished a read, Refresh was asked since, or what it has is old.
    func needsLoad(_ section: AppWorkspaceSection, refreshCount: Int) -> Bool {
        guard let stamp = stamps[section] else { return true }
        return !stamp.isFresh(refreshCount: refreshCount, now: now(), maximumAge: maximumAge)
    }

    /// `section` finished a read that was started under `refreshCount`.
    func didLoad(_ section: AppWorkspaceSection, refreshCount: Int) {
        stamps[section] = SectionLoadStamp(refreshCount: refreshCount, date: now())
    }

    /// The Store Page's model, loaded, for the version's checks (What's
    /// New in every language): the kept one, waiting for its read ahead,
    /// else one `make` makes and this keeps. Nil when it couldn't load.
    func loadedStorePage(making make: () -> StorePageViewModel) async -> StorePageViewModel? {
        await finishWarming(.storePage)
        let page = storePage ?? make()
        storePage = page
        if !page.isLoaded { await page.load() }
        return page.isLoaded ? page : nil
    }

    // MARK: - Reading ahead

    /// True while `section` is read ahead.
    func isWarming(_ section: AppWorkspaceSection) -> Bool {
        warming[section] != nil
    }

    /// Reads `section` ahead with `read` and returns once it's done. The
    /// read isn't cancelled with the caller: a model left half read would
    /// show an error for a read nobody asked for. Asked again while it
    /// runs, it waits for that read instead of starting another.
    func warm(_ section: AppWorkspaceSection, with read: @escaping @MainActor @Sendable () async -> Void) async {
        if let running = warming[section] {
            await running.value
            return
        }
        let task = Task { await read() }
        warming[section] = task
        await task.value
        warming[section] = nil
    }

    /// Waits for `section`'s read ahead, if one runs, so opening the
    /// section shows what it found instead of reading again.
    func finishWarming(_ section: AppWorkspaceSection) async {
        await warming[section]?.value
    }
}

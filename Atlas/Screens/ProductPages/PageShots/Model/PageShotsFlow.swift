//
//  PageShotsFlow.swift
//  Atlas
//

import Foundation
import Observation

/// Make Screenshots for This Page (board 52) for one page: starts the run
/// with the page's note as its angle and asks the person's assistant for
/// the plan, lays the set out once the person starts Autopilot, asks for
/// changes, and puts the set in Review & Push. Starting Claude Code,
/// stopping it and copying a prompt come in from the view, so DEBUG scenes
/// and tests can stand in for them.
@MainActor
@Observable
final class PageShotsFlow {
    let app: StoreApp
    let page: ProductPage
    let studio: PageShotsStudio
    let queue: ChangeQueue
    let screenshots: any ScreenshotsServices
    /// The page's languages (the default page's), primary first.
    let languages: [String]
    /// The languages the page has content of its own in.
    let ownLocales: [String]
    let note: String

    private(set) var source: PageShotsSource?
    /// The prompt, copied because Atlas couldn't start the assistant here.
    var copiedPrompt: String?
    /// Why the set can't be made yet, or what went wrong reading it.
    var problem: String?
    /// The text of Ask for Changes…, while it's open.
    var changeRequest: String?

    @ObservationIgnored var launch: (ClaudeCodeRunPurpose, String) async -> UUID? = { _, _ in nil }
    @ObservationIgnored var stopClaude: (UUID) -> Void = { _ in }
    @ObservationIgnored var copy: (String) -> Void = { _ in }
    @ObservationIgnored var onToast: (ToastMessage) -> Void = { _ in }
    @ObservationIgnored var now: () -> Date = { .now }

    init(
        app: StoreApp, page: ProductPage, studio: PageShotsStudio, queue: ChangeQueue, screenshots: any ScreenshotsServices,
        languages: [String], ownLocales: [String], note: String
    ) {
        self.app = app
        self.page = page
        self.studio = studio
        self.queue = queue
        self.screenshots = screenshots
        self.languages = languages
        self.ownLocales = ownLocales
        self.note = note
    }

    var key: PageShotsRun.Key { PageShotsRun.Key(appID: app.id, pageName: page.name) }
    var run: PageShotsRun? { studio.run(key) }
    var builder: ProductPageChangeBuilder { ProductPageChangeBuilder(appID: app.id) }

    // MARK: - Starting

    /// Reads what the set is made from (once).
    func loadSource() async {
        guard source == nil else { return }
        do {
            let loaded = try await PageShotsSource.load(app: app, services: screenshots)
            source = loaded
            problem = loaded.problem
        } catch {
            problem = error.localizedDescription
        }
    }

    /// Make Screenshots for This Page…: the sheet opens on the run there is,
    /// or starts one and asks the assistant for its plan.
    func open() async {
        studio.presentedKey = key
        if let run, run.stage != .used {
            studio.update(key) { $0.isHidden = false }
            await loadSource()
            return
        }
        await start()
    }

    /// A new run, and the assistant asked for its plan.
    func start() async {
        await loadSource()
        guard let source, problem == nil else {
            studio.presentedKey = key
            return
        }
        let primary = languages.first ?? source.primary
        let run = PageShotsRun(
            id: UUID().uuidString.lowercased(), appID: app.id, pageID: page.id, pageName: page.name, note: note, stage: .planning,
            languages: languages, locales: [primary] + ownLocales.filter { $0 != primary && languages.contains($0) },
            displays: source.displays, templateName: source.template?.name ?? "", startedAt: now(), updatedAt: now()
        )
        studio.begin(run)
        studio.presentedKey = key
        await askForPlan()
    }

    /// Asks the assistant for the plan (again).
    func askForPlan() async {
        let prompt = PageShotsPrompt.plan(app: app.name, appID: app.id, page: page.name, languages: languages.count)
        await ask(prompt, change: nil)
    }

    private func ask(_ prompt: String, change: String?) async {
        copiedPrompt = nil
        let id = await launch(PageShotsPrompt.purpose(pageName: page.name), prompt)
        if id == nil { copiedPrompt = prompt; copy(prompt) }
        studio.asked(key, claudeRunID: id, change: change)
    }

    // MARK: - Plan

    func toggle(locale: String) {
        guard let run, locale != run.primaryLocale else { return }
        var chosen = run.locales
        if chosen.contains(locale) { chosen.removeAll { $0 == locale } } else { chosen.append(locale) }
        studio.choose(locales: chosen, for: key)
    }

    func toggle(display: ScreenshotDisplayType) {
        guard let run else { return }
        var chosen = run.displays
        if chosen.contains(display) {
            guard chosen.count > 1 else { return }
            chosen.removeAll { $0 == display }
        } else {
            chosen.append(display)
        }
        let order = source?.displays ?? ScreenshotDisplayType.allCases
        studio.update(key) { $0.displays = order.filter(chosen.contains) }
    }

    func editAngle(_ angle: String) {
        studio.update(key) { run in run.plan?.angle = angle }
    }

    /// The languages that can get the page's own images: those with every
    /// caption.
    var readyLocales: [String] {
        guard let plan = run?.plan else { return [] }
        return plan.completeLocales(among: languages)
    }

    var canStart: Bool {
        guard let run, run.plan != nil, source != nil, problem == nil else { return false }
        return !run.locales.isEmpty && !run.displays.isEmpty && run.stage != .making
    }

    /// Start Autopilot: lays the set out.
    func startAutopilot() {
        guard canStart, let source, let run else { return }
        if let id = run.claudeRunID, run.stage == .planning { stopClaude(id) }
        studio.make(key, source: source)
    }

    /// Cancel at Plan: the run is gone.
    func cancel() {
        if let id = run?.claudeRunID { stopClaude(id) }
        studio.remove(key)
    }

    // MARK: - Making

    /// Stop: back to Plan, with the plan as it was.
    func stopMaking() {
        studio.stopMaking(key)
    }

    /// Hide · Keeps Going.
    func hide() {
        studio.update(key) { $0.isHidden = true }
        studio.presentedKey = nil
        onToast(ToastMessage(text: String(localized: "Autopilot keeps going. The page shows the progress, and so does the menu bar icon.")))
    }

    var madeCount: Int { run?.images.count ?? 0 }

    /// "2 of 5 screenshots ready in English".
    var progressText: String {
        guard let run else { return "" }
        let total = max(1, run.expectedCount)
        let made = min(madeCount, total)
        let left = minutesLeft.map { $0 <= 1 ? String(localized: " · about a minute left") : String(localized: " · about \($0) min left") } ?? ""
        return String(localized: "\(made) of \(total) screenshots ready\(left)")
    }

    var progress: Double {
        guard let run, run.expectedCount > 0 else { return 0 }
        return min(1, Double(madeCount) / Double(run.expectedCount))
    }

    /// From how long the first ones took.
    var minutesLeft: Int? {
        guard let run, let since = run.makingSince, madeCount > 0 else { return nil }
        let each = now().timeIntervalSince(since) / Double(madeCount)
        let left = Double(max(0, run.expectedCount - madeCount)) * each
        return max(1, Int((left / 60).rounded(.up)))
    }

    // MARK: - Result

    func toggleUse(locale: String) {
        guard let run else { return }
        var chosen = run.useLocales
        if chosen.contains(locale) { chosen.removeAll { $0 == locale } } else { chosen.append(locale) }
        studio.update(key) { $0.usedLocales = PageShotsRun.ordered(chosen, by: $0.languages) }
    }

    func toggleUse(display: ScreenshotDisplayType) {
        guard let run else { return }
        var chosen = run.useDisplays
        if chosen.contains(display) { chosen.removeAll { $0 == display } } else { chosen.append(display) }
        studio.update(key) { run in run.usedDisplays = run.displays.filter(chosen.contains) }
    }

    /// Ask for Changes…: the assistant changes the set; only it is redone.
    func askForChanges(_ text: String) async {
        let request = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else { return }
        changeRequest = nil
        let prompt = PageShotsPrompt.change(app: app.name, appID: app.id, page: page.name, request: request)
        await ask(prompt, change: request)
    }

    /// Use These Screenshots: one change per language and device in Review
    /// & Push, in place of the page's earlier ones.
    func use() {
        guard let run else { return }
        let changes = changes(for: run)
        guard !changes.isEmpty else { return }
        let kept = Set(changes.map(\.id))
        for old in builder.screenshotChanges(pageID: page.id, pageName: page.name, in: queue.changes(for: app.id, section: .productPages))
            where !kept.contains(old.id)
        {
            queue.discard(id: old.id)
        }
        queue.upsert(contentsOf: changes)
        studio.update(key) { $0.stage = .used }
        studio.presentedKey = nil
        let count = run.usedImages.count
        let text = count == 1
            ? String(localized: "1 screenshot added to “\(page.name)”. It’s in Review & Push.")
            : String(localized: "\(count) screenshots added to “\(page.name)”. They’re in Review & Push.")
        onToast(ToastMessage(text: text, actionTitle: String(localized: "Review & Push")))
    }

    /// The Review & Push changes of the set as chosen at Result.
    func changes(for run: PageShotsRun) -> [PendingChange] {
        var changes: [PendingChange] = []
        for locale in run.useLocales {
            for display in run.useDisplays {
                let images = run.images(locale: locale, displayType: display)
                guard !images.isEmpty else { continue }
                let files = images.map { image in
                    ProductPageScreenshotsPush.File(
                        path: studio.url(of: image, in: run).path, fileName: image.fileName, fileSize: image.fileSize, checksum: image.checksum
                    )
                }
                let hadOwn = page.localization(locale)?.screenshotDisplayTypes.contains(display.apiValue) ?? false
                changes.append(builder.screenshotsChange(files, locale: locale, displayType: display, of: page, hadOwn: hadOwn))
            }
        }
        return changes
    }

    /// How many go to Review & Push.
    var usedCount: Int { run?.usedImages.count ?? 0 }

    /// Captions that don't fit their box, in the languages and devices used.
    var overflowing: [PageShotsImage] { run?.usedImages.filter { !$0.fits } ?? [] }
}

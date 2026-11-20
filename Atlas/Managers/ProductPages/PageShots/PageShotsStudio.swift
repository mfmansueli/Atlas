//
//  PageShotsStudio.swift
//  Atlas
//

import Foundation
import Observation

/// Every custom product page's screenshot run (board 52): the plan the
/// assistant sent, the languages and devices picked, and the images Atlas
/// laid out, kept as PNGs until Review & Push uploads them. It outlives the
/// sheet, so a hidden run keeps going: the page's editor and the menu bar
/// show it. JSON and images in Application Support when given a directory;
/// runs in memory and images in a temporary folder otherwise (tests, DEBUG
/// scenes).
@MainActor
@Observable
final class PageShotsStudio {
    static let shared = PageShotsStudio(directory: sharedDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/PageScreenshots")
    }

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return defaultDirectory
    }

    private(set) var runs: [PageShotsRun.Key: PageShotsRun] = [:]
    /// The run whose sheet is open.
    var presentedKey: PageShotsRun.Key?
    @ObservationIgnored private let directory: URL?
    /// Where images are written: the directory's, or a temporary folder.
    @ObservationIgnored let imagesRoot: URL
    @ObservationIgnored private var making: [PageShotsRun.Key: Task<Void, Never>] = [:]
    /// What each run was last made from, to lay it out again when the
    /// assistant's session ends after a change.
    @ObservationIgnored private var sources: [PageShotsRun.Key: PageShotsSource] = [:]
    /// DEBUG scenes: lays out only this many, to show Making under way.
    @ObservationIgnored var holdAfter: Int?

    init(directory: URL? = nil, runs: [PageShotsRun] = []) {
        self.directory = directory
        imagesRoot = directory ?? FileManager.default.temporaryDirectory.appending(path: "AtlasPageScreenshots-\(UUID().uuidString)")
        let saved = directory.flatMap { Self.read(at: Self.file(in: $0)) } ?? []
        for run in saved + runs { self.runs[run.key] = run }
        // What was under way when Atlas quit: the assistant's session ended
        // with it, and the layout starts over when the sheet opens.
        for run in saved where run.stage.isWorking {
            update(run.key) { run in
                run.claudeRunID = nil
                switch run.stage {
                case .planning: run.stage = .plan
                case .revising: run.stage = run.images.isEmpty ? .plan : .result
                case .making: run.stage = .plan
                default: break
                }
            }
        }
    }

    // MARK: - Reading

    func run(_ key: PageShotsRun.Key) -> PageShotsRun? { runs[key] }

    func run(appID: StoreApp.ID, pageName: String) -> PageShotsRun? {
        runs[PageShotsRun.Key(appID: appID, pageName: pageName)]
    }

    /// Runs someone is working on: the menu bar's working icon.
    var workingRuns: [PageShotsRun] {
        runs.values.filter(\.stage.isWorking).sorted { $0.pageName < $1.pageName }
    }

    /// Where a run's images are.
    func folder(of run: PageShotsRun) -> URL {
        imagesRoot.appending(path: run.appID).appending(path: run.id)
    }

    func url(of image: PageShotsImage, in run: PageShotsRun) -> URL {
        folder(of: run).appending(path: image.fileName)
    }

    // MARK: - Changing

    /// A new run, in place of the page's last one (its images go with it,
    /// unless Review & Push still has them).
    func begin(_ run: PageShotsRun) {
        if let old = runs[run.key], old.id != run.id {
            making[old.key]?.cancel()
            if old.stage != .used { try? FileManager.default.removeItem(at: folder(of: old)) }
        }
        runs[run.key] = run
        save()
    }

    /// Changes one run; nothing when there's none.
    func update(_ key: PageShotsRun.Key, _ change: (inout PageShotsRun) -> Void) {
        guard var run = runs[key] else { return }
        change(&run)
        guard run != runs[key] else { return }
        run.updatedAt = .now
        runs[key] = run
        save()
    }

    /// Cancel at Plan: the run is gone, and nothing was made.
    func remove(_ key: PageShotsRun.Key) {
        making[key]?.cancel()
        making[key] = nil
        if let run = runs[key], run.stage != .used { try? FileManager.default.removeItem(at: folder(of: run)) }
        runs[key] = nil
        if presentedKey == key { presentedKey = nil }
        save()
    }

    /// A page renamed in Atlas: its run follows it.
    func rename(_ key: PageShotsRun.Key, to name: String) {
        guard var run = runs[key] else { return }
        runs[key] = nil
        run.pageName = name
        runs[run.key] = run
        save()
    }

    /// The assistant's plan arrived, or more of its captions. A first plan
    /// waits for the person at Plan once every language has its captions
    /// (or the assistant's session is over); a plan after Ask for Changes is
    /// laid out again as soon as the languages the set is made in have
    /// theirs.
    func receive(_ plan: PageShotsPlan, for key: PageShotsRun.Key, source: PageShotsSource) {
        guard let run = runs[key] else { return }
        sources[key] = source
        let remakes = run.stage == .revising || run.stage == .result || run.stage == .used
        let complete = plan.completeLocales(among: run.languages)
        let moreToCome = run.claudeRunID != nil
        update(key) { run in
            run.plan = plan
            run.problem = nil
            guard !remakes else {
                run.stage = .revising
                return
            }
            if run.choseLocales {
                run.locales = run.locales.filter(complete.contains)
            } else {
                let suggested = plan.locales.filter(complete.contains)
                run.locales = PageShotsRun.ordered([run.primaryLocale] + suggested, by: run.languages).filter(complete.contains)
            }
            run.stage = moreToCome && complete.count < run.languages.count ? .planning : .plan
        }
        if remakes, !moreToCome || run.locales.allSatisfy(complete.contains) {
            remake(key, source: source)
        }
    }

    /// Lays the set out again after a change, in the languages it was made
    /// in that have every caption.
    private func remake(_ key: PageShotsRun.Key, source: PageShotsSource) {
        update(key) { run in
            guard let plan = run.plan else { return }
            let complete = plan.completeLocales(among: run.languages)
            run.locales = run.locales.filter(complete.contains)
            if run.locales.isEmpty { run.locales = [run.primaryLocale] }
            run.changeRequest = nil
        }
        make(key, source: source)
    }

    /// The person changed the languages at Plan.
    func choose(locales: [String], for key: PageShotsRun.Key) {
        update(key) { run in
            run.locales = PageShotsRun.ordered(locales, by: run.languages)
            run.choseLocales = true
        }
    }

    // MARK: - Making

    /// Lays out the set: every chosen language on every chosen device, the
    /// primary language first so its tiles arrive first. Runs on after the
    /// sheet hides; the run moves to Result when the last one is made.
    func make(_ key: PageShotsRun.Key, source: PageShotsSource) {
        making[key]?.cancel()
        sources[key] = source
        update(key) { run in
            run.stage = .making
            run.images = []
            run.usedLocales = nil
            run.usedDisplays = nil
            run.makingSince = .now
            run.problem = nil
        }
        making[key] = Task { [weak self] in
            await self?.layOut(key, source: source)
        }
    }

    /// Stop at Making: what was made is kept, and the run goes back to Plan.
    func stopMaking(_ key: PageShotsRun.Key) {
        making[key]?.cancel()
        making[key] = nil
        update(key) { run in
            guard run.stage == .making else { return }
            run.stage = .plan
            run.makingSince = nil
        }
    }

    /// Waits for the set to be laid out (tests, the MCP tool's reply).
    func waitUntilMade(_ key: PageShotsRun.Key) async {
        await making[key]?.value
    }

    private func layOut(_ key: PageShotsRun.Key, source: PageShotsSource) async {
        guard let run = runs[key], let plan = run.plan else { return }
        let source = await source.lookingUpStore(for: run.locales)
        let folder = folder(of: run)
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var made = 0
        var failed = 0
        for locale in run.locales {
            guard let storeLocale = StoreLocaleCatalog.locale(code: locale) else { continue }
            for display in run.displays {
                for position in plan.screens.indices {
                    guard !Task.isCancelled, runs[key]?.stage == .making, made < holdAfter ?? .max else { return }
                    guard let image = await layOutOne(position, of: plan, locale: storeLocale, display: display, source: source, in: folder)
                    else {
                        failed += 1
                        continue
                    }
                    update(key) { $0.images.append(image) }
                    made += 1
                    await Task.yield()
                }
            }
        }
        guard !Task.isCancelled else { return }
        update(key) { run in
            guard run.stage == .making else { return }
            run.stage = .result
            run.makingSince = nil
            run.changeRequest = nil
            if failed > 0 {
                run.problem = failed == 1
                    ? String(localized: "1 screenshot couldn’t be laid out. Make the set again, or leave it out.")
                    : String(localized: "\(failed) screenshots couldn’t be laid out. Make the set again, or leave them out.")
            }
        }
        making[key] = nil
    }

    /// One screenshot, written as a PNG named after its place and its
    /// checksum (a set laid out again never reads an old image).
    private func layOutOne(
        _ position: Int, of plan: PageShotsPlan, locale: StoreLocale, display: ScreenshotDisplayType, source: PageShotsSource, in folder: URL
    ) async -> PageShotsImage? {
        let caption = plan.screens[position].caption(locale.code)
        guard let render = await source.render(position: position, of: plan.screens, caption: caption, locale: locale, displayType: display)
        else { return nil }
        let checksum = ScreenshotPNG.checksum(render.data)
        let name = PageShotsImage.fileName(locale: locale.code, displayType: display, position: position, checksum: checksum)
        guard (try? render.data.write(to: folder.appending(path: name), options: .atomic)) != nil else { return nil }
        return PageShotsImage(
            locale: locale.code, displayType: display, position: position, fileName: name, fileSize: render.data.count,
            checksum: checksum, fits: render.fits
        )
    }

    // MARK: - The assistant

    /// The assistant was asked for a plan or a change.
    func asked(_ key: PageShotsRun.Key, claudeRunID: UUID?, change: String? = nil) {
        update(key) { run in
            run.claudeRunID = claudeRunID
            run.problem = nil
            run.askedAt = .now
            if let change {
                run.changeRequest = change
                run.stage = .revising
            } else {
                run.stage = .planning
            }
        }
    }

    /// The launcher's word that a Claude Code session ended: a plan that
    /// came in part goes to Plan with what it has, a change that came is
    /// laid out, and one that didn't come says so calmly; what was there
    /// stays.
    func claudeRunEnded(_ session: ClaudeCodeRun) {
        guard case .pageScreenshots = session.purpose,
              let run = runs.values.first(where: { $0.appID == session.appID && $0.claudeRunID == session.id })
        else { return }
        let key = run.key
        let changed = run.plan.map { plan in run.askedAt.map { plan.madeAt >= $0 } ?? true } ?? false
        update(key) { run in
            run.claudeRunID = nil
            guard run.stage == .planning else { return }
            run.stage = .plan
            guard let plan = run.plan else {
                run.problem = String(localized: "Claude Code stopped before it sent a plan. Ask it again.")
                return
            }
            let missing = run.languages.count - plan.completeLocales(among: run.languages).count
            if missing > 0 {
                run.problem = missing == 1
                    ? String(localized: "1 language has no captions yet, so it keeps the default page’s screenshots.")
                    : String(localized: "\(missing) languages have no captions yet, so they keep the default page’s screenshots.")
            }
        }
        guard run.stage == .revising else { return }
        if changed, let source = sources[key] {
            remake(key, source: source)
        } else {
            update(key) { run in
                run.stage = run.images.isEmpty ? .plan : .result
                run.changeRequest = nil
                run.problem = String(localized: "Claude Code stopped before it changed the set. The set is as it was.")
            }
        }
    }

    #if DEBUG
    /// DEBUG scenes: these runs, and the one whose sheet is open.
    func load(_ runs: [PageShotsRun], presenting key: PageShotsRun.Key? = nil) {
        self.runs = Dictionary(runs.map { ($0.key, $0) }) { $1 }
        presentedKey = key
    }
    #endif

    // MARK: - Files

    private func save() {
        guard let directory else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let saved = runs.values.sorted { ($0.appID, $0.pageName) < ($1.appID, $1.pageName) }
        try? encoder.encode(saved).write(to: Self.file(in: directory), options: .atomic)
    }

    private static func file(in directory: URL) -> URL {
        directory.appending(path: "runs.json")
    }

    private static func read(at url: URL) -> [PageShotsRun]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([PageShotsRun].self, from: data)
    }
}

//
//  AutopilotRecapturePlanFromCaptures.swift
//  Atlas
//

import Foundation

/// The plan a capture-only run follows when the app has no saved Autopilot
/// run to open again: read from the captures the set uses today (what
/// list_captures returns). Alba's run was gone, but its 18 Japanese
/// captures (iPhone, iPhone Duo and iPad × 6 slots) were not, and
/// `request_recapture` had refused to redo them.
///
/// - Screens: one a slot, named as the set names it, else as its capture
///   files are (`ja/iPhone 17 Pro Max-01_Today's phrase.png` → "Today's
///   phrase"), with the primary language's caption.
/// - Devices: the ones with captures; iPhone Duo in the pose each slot's
///   capture shows (open, closed, or both side by side).
/// - Languages: the ones with captures of their own; `get_capture_plan`
///   gives each its launch and test arguments, as in any run.
/// - Steps, simulator setup and sample data: the open plan's, then what
///   `update_capture_plan` sent for the next plan, when there is either.
///
/// The run it makes (`run(id:appID:uploadToken:now:)`) is a finished one
/// with those captures, so `openRecapture` opens it again for some of
/// them as it does a saved run: the template and captions stay, and Review
/// & Push sends only the images that change. Pure.
struct AutopilotRecapturePlanFromCaptures: Codable, Hashable, Sendable {
    var plan: AutopilotPlan
    /// The set's captures as the run's, one a target.
    var captures: [AutopilotCapture]
    /// The set's template version now.
    var templateVersion: Int?
    var versionString: String

    /// Nil when the set has no captures on the slots.
    init?(
        document: ScreenshotsDocument, primaryLocale: String, versionString: String, proposals: AutopilotPlanProposals = AutopilotPlanProposals(),
        openPlan: AutopilotPlan? = nil
    ) {
        let index = document.captures.captures
        guard !index.isEmpty else { return nil }
        let screens = Self.screens(in: document, primary: primaryLocale, steps: openPlan)
        var displays = ScreenshotDisplayType.studio.filter { display in index.contains { $0.displayType == display } }
        let own = document.captures.localesWithOwnInterface()
        let locales = (own.contains(primaryLocale) ? [primaryLocale] : []) + own.filter { $0 != primaryLocale }
        guard !screens.isEmpty, !locales.isEmpty else { return nil }

        var plan = AutopilotPlan(screens: screens, displayTypes: [], localeCodes: locales, primaryLocale: primaryLocale)
        for display in ScreenshotDisplayType.ownScreens where displays.contains(display) {
            let set = Self.ownScreens(on: display, in: document, setScreens: screens)
            if set.isEmpty { displays.removeAll { $0 == display } } else { plan.setScreens(set, on: display) }
        }
        plan.displayTypes = displays
        plan.assistantChoosesScreens = false
        plan.screenshotStyle = .keep
        plan.simulator = openPlan?.simulator ?? AutopilotSimulatorSetup()
        plan.writtenFrom = openPlan?.writtenFrom
        if displays.contains(.iPhoneDuo) { Self.setDuoPoses(of: &plan, from: document) }
        for change in proposals.changes {
            change.apply(to: &plan)
        }

        let found = plan.targets.compactMap { target in Self.capture(of: target, in: document, plan: plan) }
        guard !found.isEmpty else { return nil }
        self.plan = plan
        captures = found
        templateVersion = document.history?.currentNumber
        self.versionString = versionString
    }

    /// The targets the set has a capture of: the only ones a request can
    /// redo.
    var capturedTargets: Set<AutopilotCaptureTarget> {
        Set(captures.map(\.target))
    }

    /// The finished run of these captures, for a capture-only run to open
    /// again.
    func run(id: String, appID: StoreApp.ID, uploadToken: String, now: Date) -> AutopilotRun {
        var run = AutopilotRun(
            id: id, appID: appID, versionString: versionString, stage: .ready, plan: plan, designKind: .none, designName: nil,
            uploadToken: uploadToken, createdAt: now
        )
        let dates = captures.map(\.receivedAt).filter { $0 != .distantPast }
        run.captures = captures
        run.templateVersion = templateVersion
        run.startedAt = dates.min() ?? now
        run.finishedAt = dates.max() ?? now
        let count = captures.count
        run.appendLog(String(localized: "No Autopilot run was saved: the plan comes from the set’s \(count) captures"), kind: .event, at: now)
        return run
    }

    // MARK: - Screens

    /// One screen a slot: named as the set names it, else after its
    /// capture files; the steps the open plan has for it.
    private static func screens(in document: ScreenshotsDocument, primary: String, steps plan: AutopilotPlan?) -> [AutopilotScreen] {
        (0..<document.slotCount).map { slot in
            let named = document.slotNames.indices.contains(slot) ? document.slotNames[slot].trimmingCharacters(in: .whitespaces) : ""
            let name = named.isEmpty ? (fileSlotName(slot: slot, in: document) ?? document.slotName(slot)) : named
            let id = screenID(name, slot: slot)
            let caption = document.captions.caption(locale: primary, slot: slot)?.headline ?? ""
            let planned = plan?.screens.first { $0.id == id } ?? plan?.screens.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
            return AutopilotScreen(id: id, name: name, steps: planned?.steps ?? "", caption: caption)
        }
    }

    /// "today-s-phrase-1", as Run Autopilot… names a slot's screen
    /// (`AutopilotPlanner.screens(from:primary:)`); "screen-1" for a name
    /// with no letters.
    static func screenID(_ name: String, slot: Int) -> String {
        let hasLetters = name.contains { $0.isLetter || $0.isNumber }
        return (hasLetters ? AutopilotScreen.identifier(for: name) : "screen") + "-\(slot + 1)"
    }

    /// The name a slot's capture files give it: the primary language's
    /// iPhone one first.
    private static func fileSlotName(slot: Int, in document: ScreenshotsDocument) -> String? {
        let order = ScreenshotDisplayType.standard + [.mac]
        let files = document.captures.captures
            .filter { $0.slot == slot && $0.isCompanion != true && order.contains($0.displayType) }
            .sorted { (order.firstIndex(of: $0.displayType) ?? 9) < (order.firstIndex(of: $1.displayType) ?? 9) }
        let primary = files.filter { $0.locale == document.scope.primary } + files
        // "ja/iPhone 17 Pro Max-01_Today's phrase.png" → "Today's phrase".
        return primary.lazy.compactMap { CaptureFileName(($0.fileName as NSString).lastPathComponent).slotName }.first
    }

    /// Apple Watch's and Apple Vision Pro's own screens, as the set names
    /// them; an Apple Vision Pro window follows the set's screen whose
    /// caption it carries.
    private static func ownScreens(on display: ScreenshotDisplayType, in document: ScreenshotsDocument, setScreens: [AutopilotScreen]) -> [AutopilotScreen] {
        let prefix = display == .watch ? "watch" : "vision"
        return (document.screens(on: display) ?? []).enumerated().map { index, screen in
            let source = screen.captionSlot.flatMap { setScreens.indices.contains($0) ? setScreens[$0].id : nil }
            return AutopilotScreen(id: "\(prefix)-" + screenID(screen.name, slot: index), name: screen.name, sourceScreenID: source)
        }
    }

    // MARK: - iPhone Duo

    /// iPhone Duo's row as the set's captures have it: the cover display's
    /// size is closed, any other open, and a slot with the cover display
    /// beside the inner one both. One pose for every slot is the Duo row's
    /// own choice; mixed, each slot keeps its own (`duoSlotPoses`). A set
    /// with Duo screens of its own is separate screenshots.
    private static func setDuoPoses(of plan: inout AutopilotPlan, from document: ScreenshotsDocument) {
        if !(document.screens(on: .iPhoneDuo) ?? []).isEmpty {
            plan.runChoice.duoScreens = .both
            plan.runChoice.duoBoth = .separate
            return
        }
        let duo = document.captures.captures.filter { $0.displayType == .iPhoneDuo }
        let poses: [[AutopilotDuoPose]] = plan.screens.indices.map { slot in
            let own = duo.filter { $0.slot == slot && $0.isCompanion != true }
            let closed = own.count(where: { CaptureSizeRules.isDuoOuterDisplay($0.pixelSize) })
            let main: AutopilotDuoPose = closed * 2 > own.count ? .closed : .open
            let paired = duo.contains { $0.slot == slot && $0.isCompanion == true }
            return paired ? [.open, .closed] : [main]
        }
        let kinds = Set(poses)
        if kinds == [[.open]] {
            plan.runChoice.duoScreens = .inner
        } else if kinds == [[.closed]] {
            plan.runChoice.duoScreens = .cover
        } else if kinds == [[.open, .closed]] {
            plan.runChoice.duoScreens = .both
            plan.runChoice.duoBoth = .sideBySide
        } else {
            plan.runChoice.duoScreens = .both
            plan.runChoice.duoSlotPoses = poses
        }
    }

    // MARK: - Captures

    /// The set's capture a target stands for: on its slot (iPhone Duo's
    /// where the plan puts its pose), in its language, as a capture of the
    /// run that made it. Nil when the set has none there, or one of another
    /// pose.
    private static func capture(of target: AutopilotCaptureTarget, in document: ScreenshotsDocument, plan: AutopilotPlan) -> AutopilotCapture? {
        guard let placed = AutopilotRecaptureTargets.documentSlot(of: target, in: plan) else { return nil }
        let isCompanion = placed.isCompanion
        guard let found = document.captures.captures.first(where: {
            $0.locale == target.locale && $0.displayType == target.displayType && $0.slot == placed.slot && ($0.isCompanion == true) == isCompanion
        }) else { return nil }
        let capture = AutopilotCapture(
            id: "set-" + target.key, target: target, attempt: 1, score: 1, notes: "", captureID: found.id, pixelSize: found.pixelSize,
            receivedAt: found.importedAt ?? .distantPast
        )
        return plan.fits(capture) ? capture : nil
    }
}

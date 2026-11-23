//
//  PageShotsProposal.swift
//  Atlas
//

import Foundation

/// A plan `propose_page_screenshots` sent, checked like the person's own
/// captions are: the default set's screens, each once, at most 10; every
/// caption in one of the page's languages, within App Review's rules and
/// fitting the template's caption box on every device the set is made
/// for. The primary language needs every screen's caption, or nothing is
/// kept; another language's caption that fails is left out and said, so
/// the assistant fixes it and sends it again. A screen keeps the captions
/// Atlas has for it unless they're sent again, wherever it moves.
@MainActor
struct PageShotsProposal {
    /// A caption left out, and why.
    struct Refusal: Hashable, Sendable {
        /// 1-based.
        var place: Int
        var locale: String
        var reason: String

        var json: JSONValue {
            ["place": .int(place), "locale": .string(locale), "reason": .string(reason)]
        }
    }

    enum Outcome {
        case planned(PageShotsPlan, refused: [Refusal])
        case refused(String, refused: [Refusal])
    }

    static let maxScreens = 10
    static let maxAngle = 200
    static let maxReason = AssistantTextLimits.why

    let run: PageShotsRun
    let source: PageShotsSource

    func check(
        angle rawAngle: String?, reason rawReason: String?, screens items: [JSONValue], locales: [String]?, client: String,
        layers: SuggestionLayers? = nil
    ) -> Outcome {
        let angle = rawAngle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? run.plan?.angle ?? ""
        let reason = rawReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? run.plan?.reason ?? ""
        if let problem = textProblem(angle: angle, reason: reason) { return .refused(problem, refused: []) }
        let order: [Int]
        switch self.order(of: items) {
        case let .success(slots): order = slots
        case let .failure(problem): return .refused(problem.message, refused: [])
        }
        let (screens, unsorted) = merged(items, order: order)
        var refused = unsorted
        let primary = run.primaryLocale
        refused.sort { first, second in
            let firstKey = (first.locale == primary ? 0 : 1, first.locale, first.place)
            let secondKey = (second.locale == primary ? 0 : 1, second.locale, second.place)
            return firstKey < secondKey
        }
        let missing = screens.indices.filter { screens[$0].caption(primary) == nil }.map { $0 + 1 }
        if !missing.isEmpty {
            let places = missing.map(String.init).formatted(.list(type: .and))
            let message = String(localized: """
            Every screenshot needs a caption in \(primary), the page’s primary language, that Atlas can keep: place \(places) \
            hasn’t one. Nothing was kept.
            """)
            return .refused(message, refused: refused)
        }
        let asked: [String] = locales ?? run.plan?.locales ?? [primary]
        let suggested = asked.compactMap { StoreLocaleCatalog.resolve($0).locale?.code }
        let plan = PageShotsPlan(
            angle: angle, screens: screens, locales: PageShotsRun.ordered(suggested + [primary], by: run.languages),
            reason: reason, source: client, madeAt: .now, layers: layers ?? (rawReason == nil ? run.plan?.layers : nil)
        )
        return .planned(plan, refused: refused)
    }

    /// The plan's screens in `order` with the captions sent on top of the
    /// ones Atlas has for each screen, and the captions left out.
    private func merged(_ items: [JSONValue], order: [Int]) -> ([PageShotsScreen], [Refusal]) {
        // Each screen keeps the captions Atlas has for it unless they're sent
        // again; a screen left out goes with its captions.
        let previous = run.plan?.screens ?? []
        var screens = order.map { slot in
            PageShotsScreen(slot: slot, captions: previous.first { $0.slot == slot }?.captions ?? [:])
        }
        var refused: [Refusal] = []
        var sent: Set<String> = []
        for (place, item) in items.enumerated() {
            for (code, value) in item["captions"]?.objectValue ?? [:] {
                let locale = StoreLocaleCatalog.resolve(code).locale?.code ?? code
                sent.insert("\(place)|\(locale)")
                switch caption(value, code: code, place: place, screens: screens) {
                case let .success((locale, caption)): screens[place].captions[locale] = caption
                case let .failure(failure): refused.append(failure.refusal)
                }
            }
        }
        refused += recheckMoved(&screens, previous: previous, sent: sent)
        // A refused primary caption doesn't fall back on an older one.
        for refusal in refused where refusal.locale == run.primaryLocale {
            screens[refusal.place - 1].captions[refusal.locale] = nil
        }
        return (screens, refused)
    }

    /// A kept caption of a screen that moved takes the design of its new
    /// place: it's checked there again, and left out when it doesn't fit.
    private func recheckMoved(_ screens: inout [PageShotsScreen], previous: [PageShotsScreen], sent: Set<String>) -> [Refusal] {
        var refused: [Refusal] = []
        for place in screens.indices where previous.firstIndex(where: { $0.slot == screens[place].slot }) != place {
            for (locale, kept) in screens[place].captions where !sent.contains("\(place)|\(locale)") {
                let value: JSONValue = ["headline": .string(kept.headline), "subhead": kept.subhead.map(JSONValue.string) ?? .null]
                guard case let .failure(failure) = caption(value, code: locale, place: place, screens: screens) else { continue }
                screens[place].captions[locale] = nil
                var refusal = failure.refusal
                refusal.reason = String(localized: "The caption kept from the plan before: \(refusal.reason)")
                refused.append(refusal)
            }
        }
        return refused
    }

    private func textProblem(angle: String, reason: String) -> String? {
        if angle.isEmpty {
            return String(localized: "Send `angle`: the page’s story in a sentence, e.g. “Privacy first: the lock, then writing, then search.”")
        }
        if angle.count > Self.maxAngle { return String(localized: "`angle` is \(angle.count) characters; keep it to \(Self.maxAngle).") }
        if let refusal = AssistantTextLimits.whyRefusal(reason, field: "reason") { return refusal }
        return nil
    }

    /// The default set's slots (0-based), in the page's order.
    private func order(of items: [JSONValue]) -> Result<[Int], OrderProblem> {
        let count = source.slotCount
        guard !items.isEmpty, items.count <= Self.maxScreens else {
            return .failure(OrderProblem(String(localized: "Send 1 to \(Self.maxScreens) screens: App Store Connect takes 10 screenshots a set.")))
        }
        var slots: [Int] = []
        for item in items {
            guard let number = item["screen"]?.intValue, (1...max(1, count)).contains(number), count > 0 else {
                return .failure(OrderProblem(String(localized: """
                Each item’s `screen` is one of the default set’s screens, 1 to \(count), as get_page_screenshots lists them.
                """)))
            }
            guard !slots.contains(number - 1) else {
                return .failure(OrderProblem(String(localized: "Screen \(number) is there twice: use each screen once.")))
            }
            slots.append(number - 1)
        }
        return .success(slots)
    }

    struct OrderProblem: Error {
        var message: String
        init(_ message: String) { self.message = message }
    }

    private func caption(
        _ value: JSONValue, code: String, place: Int, screens: [PageShotsScreen]
    ) -> Result<(String, PageShotsCaption), CaptionRefusal> {
        func refuse(_ locale: String, _ reason: String) -> Result<(String, PageShotsCaption), CaptionRefusal> {
            .failure(CaptionRefusal(Refusal(place: place + 1, locale: locale, reason: reason)))
        }
        guard let locale = StoreLocaleCatalog.resolve(code).locale else {
            return refuse(code, String(localized: "“\(code)” isn’t an App Store locale."))
        }
        guard run.languages.contains(locale.code) else {
            let languages = run.languages.formatted(.list(type: .and))
            return refuse(locale.code, String(localized: "The page isn’t in \(locale.code): write captions in \(languages)."))
        }
        let caption = PageShotsCaption(headline: value["headline"]?.stringValue ?? value.stringValue ?? "", subhead: value["subhead"]?.stringValue)
        guard !caption.isEmpty else { return refuse(locale.code, String(localized: "The headline is empty.")) }
        let issues = StoreTextGuidelineCheck.issues(inCaption: caption.headline, subhead: caption.subhead)
        guard issues.isEmpty else { return refuse(locale.code, ProposeCaptionsTool.guidelineRefusal(issues)) }
        for display in run.displays {
            guard let layout = source.layout(position: place, of: screens, caption: caption, locale: locale, displayType: display) else {
                return refuse(locale.code, String(localized: "Atlas couldn’t lay this screenshot out on \(display.title)."))
            }
            if let problem = layout.headlineFont.problem { return refuse(locale.code, problem) }
            if !layout.headline.fits {
                return refuse(locale.code, String(localized: "The headline \(layout.headline.refusalText) on \(display.title). Write it shorter."))
            }
            if let subhead = layout.subhead, !subhead.fits {
                return refuse(locale.code, String(localized: "The subhead \(subhead.refusalText) on \(display.title). Write it shorter."))
            }
        }
        return .success((locale.code, caption))
    }

    struct CaptionRefusal: Error {
        var refusal: Refusal
        init(_ refusal: Refusal) { self.refusal = refusal }
    }
}

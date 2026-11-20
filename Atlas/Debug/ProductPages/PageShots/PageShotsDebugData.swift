//
//  PageShotsDebugData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Private diary's screenshot plan (board 52), as Claude Code would send
/// it: privacy first, the Face ID lock, then writing, search, photos and
/// the week, in English, German and Arabic.
enum PageShotsDebugData {
    static let order = [4, 0, 2, 3, 1]

    static let captions: [String: [PageShotsCaption]] = [
        "en-US": [
            PageShotsCaption(headline: "Locked with Face ID"),
            PageShotsCaption(headline: "Write what you can’t say out loud"),
            PageShotsCaption(headline: "Find any day in a second"),
            PageShotsCaption(headline: "Your photos stay with you"),
            PageShotsCaption(headline: "Look back on your week"),
        ],
        "de-DE": [
            PageShotsCaption(headline: "Mit Face ID gesperrt"),
            PageShotsCaption(headline: "Schreib, was du nicht laut sagst"),
            PageShotsCaption(headline: "Jeden Tag sofort finden"),
            PageShotsCaption(headline: "Deine Fotos bleiben bei dir"),
            PageShotsCaption(headline: "Deine Woche im Rückblick"),
        ],
        "ar-SA": [
            PageShotsCaption(headline: "مقفل ببصمة الوجه"),
            PageShotsCaption(headline: "اكتب ما لا تقوله بصوت عالٍ"),
            PageShotsCaption(headline: "اعثر على أي يوم في ثانية"),
            PageShotsCaption(headline: "صورك تبقى معك"),
            PageShotsCaption(headline: "راجع أسبوعك"),
        ],
    ]

    static var plan: PageShotsPlan {
        let screens = order.enumerated().map { place, slot in
            PageShotsScreen(slot: slot, captions: captions.compactMapValues { $0.indices.contains(place) ? $0[place] : nil })
        }
        return PageShotsPlan(
            angle: "Privacy first. Open with the Face ID lock, then writing, then search. Leave the week for later in the set.",
            screens: screens, locales: ["en-US", "ar-SA"],
            reason: "People who search “private diary” want to know nobody else can read it: the lock comes first, then that entries stay on the device.",
            source: "Claude Code", madeAt: DebugProductPagesData.now
        )
    }

    /// The run of `flow`'s page at `stage`.
    @MainActor
    static func run(for flow: PageShotsFlow, stage: PageShotsStage) -> PageShotsRun {
        PageShotsRun(
            id: "debug-\(ProductPageBrief.key(flow.page.name).replacingOccurrences(of: " ", with: "-"))",
            appID: flow.app.id, pageID: flow.page.id, pageName: flow.page.name, note: flow.note,
            stage: stage == .planning ? .planning : .plan, plan: stage == .planning ? nil : plan,
            languages: flow.languages, locales: stage == .planning ? ["en-US"] : ["en-US", "ar-SA"],
            displays: [.iPhone, .iPad], templateName: "", claudeRunID: stage == .planning ? UUID() : nil,
            startedAt: DebugProductPagesData.now, updatedAt: DebugProductPagesData.now
        )
    }
}
#endif

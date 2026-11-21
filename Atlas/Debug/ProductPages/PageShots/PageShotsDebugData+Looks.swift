//
//  PageShotsDebugData+Looks.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Board 52's new look from Claude Design in the DEBUG scenes: three looks
/// laid on starters, and Privacy's lock captured again on iPhone and iPad.
extension PageShotsDebugData {
    static let looks: [(name: String, rationale: String, starter: TemplateStarter)] = [
        ("Quiet Indigo", "Deep blue and lots of room: a diary that feels closed to everyone else.", .cinema),
        ("Paper Lock", "Warm paper and a bold headline, like a notebook with a clasp.", .poster),
        ("Night Mode", "Dark and calm, for people who write before sleep.", .spotlight),
    ]

    @MainActor
    static func apply(_ looks: PageShotsDebugSetup.Looks, to flow: PageShotsFlow) {
        let studio = flow.studio
        let key = flow.key
        studio.choose(look: .claudeDesign, for: key)
        studio.askedForLooks(key, claudeRunID: looks == .drawing ? UUID() : nil)
        let count = looks == .drawing ? 1 : Self.looks.count
        for (index, look) in Self.looks.prefix(count).enumerated() {
            let template = ScreenshotTemplate.starter(look.starter, id: flow.app.id, title: flow.app.name, slotCount: flow.source?.slotCount ?? 5)
            _ = studio.receive(look: PageShotsLookCandidate(
                id: "debug-look-\(index + 1)", name: look.name, rationale: look.rationale, template: template, link: nil,
                source: "Claude Code", receivedAt: DebugProductPagesData.now
            ), for: key)
        }
        guard looks == .chosen else { return }
        studio.pick(lookID: "debug-look-2", for: key)
        studio.setRecapture(true, for: key)
        for display in [ScreenshotDisplayType.iPhone, .iPad] {
            _ = studio.receive(capture: PageShotsNewCapture(
                slot: 4, locale: "en-US", displayType: display, captureID: "debug-lock-\(display.rawValue)",
                pixelSize: display.portraitPixelSize, notes: "The diary locked with Face ID.", receivedAt: DebugProductPagesData.now
            ), for: key)
        }
    }
}
#endif

//
//  PreviewShotsStrip.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// What the App Store preview's screenshot strip shows in a language: the
/// first screenshots people swipe through (an iPhone set's when there is
/// one), each loading until its image downloads, so the strip never just
/// looks empty while it waits. A language without any shows the primary
/// language's, and says so.
struct PreviewShotsStrip {
    /// How many screenshots the strip shows.
    static let count = 3
    /// An iPhone's portrait screenshot: the tile's shape until the
    /// screenshot's own is known.
    static let placeholderAspect: CGFloat = 2.16

    private(set) var slots: [PreviewShotSlot]
    /// The screenshots are the primary language's, as this one has none.
    private(set) var isBorrowed = false
    /// The screenshots whose images are still to download.
    private(set) var pending: [LiveScreenshot] = []
    /// The app's live screenshots couldn't be read.
    private(set) var isUnreadable = false

    /// While the app's live screenshots are read.
    static var reading: PreviewShotsStrip {
        PreviewShotsStrip(slots: placeholders(.loading))
    }

    /// The app's live screenshots couldn't be read.
    static var unreadable: PreviewShotsStrip {
        var strip = PreviewShotsStrip(slots: placeholders(.unavailable))
        strip.isUnreadable = true
        return strip
    }

    private init(slots: [PreviewShotSlot]) {
        self.slots = slots
    }

    /// The screenshots `locale` shows, each loading.
    init(live: LiveScreenshots, locale: StoreLocale, primary: StoreLocale) {
        let own = Self.bestSet(in: live, locale: locale)
        let set = own ?? Self.bestSet(in: live, locale: primary)
        let shots = Array((set?.screenshots ?? []).prefix(Self.count))
        guard !shots.isEmpty else {
            slots = Self.placeholders(.unavailable)
            return
        }
        isBorrowed = own == nil
        slots = shots.map { PreviewShotSlot(id: $0.id, aspect: Self.aspect(of: $0), phase: .loading) }
        pending = shots
    }

    var isLoading: Bool {
        slots.contains { $0.phase.isLoading }
    }

    /// A screenshot's image arrived, or couldn't be downloaded. The tile
    /// takes the image's own shape when App Store Connect didn't give one.
    mutating func finish(_ id: String, with image: CGImage?) {
        guard let index = slots.firstIndex(where: { $0.id == id && $0.phase.isLoading }) else { return }
        slots[index].phase = ImageLoadPhase(finished: image)
        pending.removeAll { $0.id == id }
        if let image, image.width > 0 {
            slots[index].aspect = CGFloat(image.height) / CGFloat(image.width)
        }
    }

    /// Shows at once every screenshot whose image is already here (`kept`
    /// gives it), so a strip seen before never spins again.
    mutating func finishKept(_ kept: (LiveScreenshot) -> CGImage?) {
        for shot in pending {
            if let image = kept(shot) { finish(shot.id, with: image) }
        }
    }

    /// What VoiceOver (and the UI tests) hear for the whole strip.
    var accessibilityLabel: String {
        if isLoading { return String(localized: "Loading screenshots") }
        if isUnreadable { return String(localized: "Screenshots couldn’t be read") }
        if slots.allSatisfy(\.isPlaceholder) { return String(localized: "No screenshots yet") }
        let shown = slots.filter { $0.phase.image != nil }.count
        if shown == slots.count {
            return shown == 1 ? String(localized: "1 screenshot") : String(localized: "\(shown) screenshots")
        }
        return String(localized: "\(shown) of \(slots.count) screenshots shown")
    }

    /// An iPhone set first: it's what most people see.
    static func bestSet(in live: LiveScreenshots, locale: StoreLocale) -> LiveScreenshotSet? {
        let sets = live.screenshotSets.filter { $0.locale == locale.code && !$0.screenshots.isEmpty }
        return sets.first { $0.displayType == .iPhone } ?? sets.first
    }

    private static func placeholders(_ phase: ImageLoadPhase) -> [PreviewShotSlot] {
        (0..<count).map { PreviewShotSlot(id: "placeholder.\($0)", aspect: placeholderAspect, phase: phase, isPlaceholder: true) }
    }

    private static func aspect(of shot: LiveScreenshot) -> CGFloat {
        guard let size = shot.pixelSize, size.width > 0, size.height > 0 else { return placeholderAspect }
        return CGFloat(size.height) / CGFloat(size.width)
    }
}

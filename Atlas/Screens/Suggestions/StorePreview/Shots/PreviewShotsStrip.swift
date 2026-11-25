//
//  PreviewShotsStrip.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// What the App Store preview's row shows in a language, in the App
/// Store's order: the App Previews first (poster frame and length), then
/// every screenshot of the set (an iPhone set's when there is one), each
/// loading until its image downloads, so the row never looks empty while
/// it waits. A language without any shows the primary language's, and says
/// so.
struct PreviewShotsStrip {
    /// How many grey tiles stand in while the sets are read, or when
    /// there's nothing to show.
    static let placeholderCount = 3
    /// An iPhone's portrait screenshot: the tile's shape until the
    /// screenshot's own is known.
    static let placeholderAspect: CGFloat = 2.16

    private(set) var slots: [PreviewShotSlot]
    /// The set's App Previews, which the App Store plays before the
    /// screenshots.
    private(set) var appPreviews: [PreviewAppPreviewSlot] = []
    /// The screenshots are the primary language's, as this one has none.
    private(set) var isBorrowed = false
    /// The screenshots whose images are still to download.
    private(set) var pending: [LiveScreenshot] = []
    /// The app's live screenshots couldn't be read.
    private(set) var isUnreadable = false
    /// The sets are still being read: the row is a grey skeleton.
    private(set) var isReading = false

    /// While the app's live screenshots are read.
    static var reading: PreviewShotsStrip {
        var strip = PreviewShotsStrip(slots: placeholders(.loading))
        strip.isReading = true
        return strip
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

    /// The App Previews and screenshots `locale` shows, each loading.
    init(live: LiveScreenshots, locale: StoreLocale, primary: StoreLocale) {
        let own = Self.bestSet(in: live, locale: locale)
        let set = own ?? Self.bestSet(in: live, locale: primary)
        let shots = set?.screenshots ?? []
        guard let set, !shots.isEmpty else {
            slots = Self.placeholders(.unavailable)
            return
        }
        isBorrowed = own == nil
        slots = shots.map { PreviewShotSlot(id: $0.id, aspect: Self.aspect(of: $0), phase: .loading) }
        pending = shots
        appPreviews = Self.appPreviews(live.previews(locale: set.locale, displayType: set.displayType), aspect: slots.first?.aspect)
    }

    /// The row's tiles, App Previews first.
    var items: [PreviewRailItem] {
        appPreviews.map(PreviewRailItem.appPreview) + slots.map(PreviewRailItem.screenshot)
    }

    /// How many real screenshots the row shows (none while it stands in).
    var screenshotCount: Int {
        slots.count { !$0.isPlaceholder }
    }

    var isLoading: Bool {
        slots.contains { $0.phase.isLoading } || appPreviews.contains { $0.poster.isLoading }
    }

    /// The App Previews whose poster frame is still to download.
    var pendingPosters: [PreviewAppPreviewSlot] {
        appPreviews.filter { $0.preview != nil && $0.poster.isLoading }
    }

    /// The line under the row; nil while it's read or has nothing.
    func caption(overflows: Bool) -> String? {
        guard !isReading, !isUnreadable else { return nil }
        return PreviewRailCaption.text(appPreviews: appPreviews.count, screenshots: screenshotCount, overflows: overflows)
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

    /// An App Preview's poster frame arrived, or there's none to show.
    mutating func finishPoster(_ id: String, with image: CGImage?) {
        guard let index = appPreviews.firstIndex(where: { $0.id == id && $0.poster.isLoading }) else { return }
        appPreviews[index].poster = ImageLoadPhase(finished: image)
        if let image, image.width > 0 {
            appPreviews[index].aspect = CGFloat(image.height) / CGFloat(image.width)
        }
    }

    /// An App Preview's length, once read from its movie.
    mutating func setSeconds(_ seconds: Int?, for id: String) {
        guard let seconds, let index = appPreviews.firstIndex(where: { $0.id == id }) else { return }
        appPreviews[index].seconds = seconds
    }

    /// Shows at once every screenshot whose image is already here (`kept`
    /// gives it), so a strip seen before never spins again.
    mutating func finishKept(_ kept: (LiveScreenshot) -> CGImage?) {
        for shot in pending {
            if let image = kept(shot) { finish(shot.id, with: image) }
        }
    }

    /// What VoiceOver (and the UI tests) hear for the whole row.
    var accessibilityLabel: String {
        if isLoading { return String(localized: "Loading screenshots") }
        if isUnreadable { return String(localized: "Screenshots couldn’t be read") }
        if slots.allSatisfy(\.isPlaceholder), appPreviews.isEmpty { return String(localized: "No screenshots yet") }
        let shown = slots.count { $0.phase.image != nil }
        if shown == slots.count, let counts = PreviewRailCaption.counts(appPreviews: appPreviews.count, screenshots: shown) {
            return counts
        }
        return String(localized: "\(shown) of \(slots.count) screenshots shown")
    }

    /// An iPhone set first: it's what most people see.
    static func bestSet(in live: LiveScreenshots, locale: StoreLocale) -> LiveScreenshotSet? {
        let sets = live.screenshotSets.filter { $0.locale == locale.code && !$0.screenshots.isEmpty }
        return sets.first { $0.displayType == .iPhone } ?? sets.first
    }

    /// Each App Preview of `set`, its poster frame loading (or none to
    /// load in a set read before Atlas kept each preview).
    private static func appPreviews(_ set: LiveAppPreviewSet?, aspect: CGFloat?) -> [PreviewAppPreviewSlot] {
        guard let set else { return [] }
        let previews: [LiveAppPreview?] = set.previews ?? Array(repeating: nil, count: set.previewCount)
        return previews.enumerated().map { index, preview in
            let posterAspect = preview?.posterPixelSize.flatMap { size in size.width > 0 ? CGFloat(size.height) / CGFloat(size.width) : nil }
            return PreviewAppPreviewSlot(
                id: preview?.id ?? "\(set.id).\(index)", preview: preview, locale: set.locale, displayType: set.displayType,
                aspect: posterAspect ?? aspect ?? placeholderAspect, poster: preview == nil ? .unavailable : .loading,
                // The set's length when Atlas knows it; otherwise it's read
                // from the movie.
                seconds: index == 0 ? set.durationSeconds : nil
            )
        }
    }

    private static func placeholders(_ phase: ImageLoadPhase) -> [PreviewShotSlot] {
        (0..<placeholderCount).map { PreviewShotSlot(id: "placeholder.\($0)", aspect: placeholderAspect, phase: phase, isPlaceholder: true) }
    }

    private static func aspect(of shot: LiveScreenshot) -> CGFloat {
        guard let size = shot.pixelSize, size.width > 0, size.height > 0 else { return placeholderAspect }
        return CGFloat(size.height) / CGFloat(size.width)
    }
}

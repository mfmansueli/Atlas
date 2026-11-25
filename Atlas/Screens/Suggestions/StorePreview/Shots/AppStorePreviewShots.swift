//
//  AppStorePreviewShots.swift
//  Atlas
//

import CoreGraphics
import SwiftUI

/// What people swipe through in a language, as live on the App Store, from
/// an iPhone set when there is one (`PreviewShotsStrip`): the App Preview
/// first (poster frame, play button, length), then every screenshot, in one
/// row that scrolls sideways, snaps to each tile and fades at its trailing
/// edge while there's more (README-Redesign, “On the App Store preview”).
/// The line under it counts them. While the sets are read the row is a grey
/// skeleton; then each tile shows a spinner until its image has downloaded.
/// Shown again, it draws what it read last at once (`LiveShotsMemo`,
/// images decoded before) and reads again behind it only when that's over a
/// minute old. A language without any shows the primary language's, and
/// says so. With Suggested (the Store Page's Now | Suggested), each
/// screenshot whose caption an assistant suggested is drawn by the template
/// engine with that caption, in a purple ring (`SuggestedPreviewShots`).
struct AppStorePreviewShots: View {
    let services: any ScreenshotsServices
    let app: StoreApp
    /// Each language's version localization, where screenshots live.
    let localizations: [StoreLocale: String]
    let locale: StoreLocale
    /// Whose screenshots a language without any shows.
    let primary: StoreLocale
    var width: CGFloat
    var memo: LiveShotsMemo
    /// Play on the App Preview: Screenshots on that language and device.
    var onPlay: ((_ locale: String, _ displayType: ScreenshotDisplayType) -> Void)?
    /// The Store Page's Suggested: suggested captions on the screenshots.
    var showsSuggested = false

    /// The app's live screenshots, once read; `live` nil when they
    /// couldn't be.
    @State private var read: ReadShots?
    @State private var strip: PreviewShotsStrip
    @State private var scroll = RailScroll()
    @State private var suggested = SuggestedPreviewShots.none
    /// The captures the suggested screenshots draw, by capture ID.
    @State private var suggestedCaptures: [String: CGImage] = [:]
    /// The screenshot document read for Suggested, when no Screenshots view
    /// has it loaded.
    @State private var readDocument: ScreenshotsDocument?

    private struct ReadShots: Equatable {
        var key: LiveShotsMemo.Key
        var live: LiveScreenshots?
    }

    /// Whether the row goes on past its edge, and whether some of it is
    /// still to the right of what shows.
    private struct RailScroll: Equatable {
        var overflows = false
        var hasMore = false

        init() {}

        init(_ geometry: ScrollGeometry) {
            overflows = geometry.contentSize.width > geometry.containerSize.width + 1
            hasMore = geometry.contentOffset.x + geometry.containerSize.width < geometry.contentSize.width - 1
        }
    }

    /// What Suggested draws from: changes when a caption is suggested,
    /// accepted or dismissed, or the row shows another set.
    private struct SuggestedSource: Equatable {
        var showsSuggested: Bool
        var locale: StoreLocale
        var live: LiveScreenshots?
        var document: ScreenshotsDocument?
    }

    private struct ChosenShots: Hashable {
        var key: LiveShotsMemo.Key
        var locale: StoreLocale
        /// What was read, so the images load again once it changes.
        var read: LiveScreenshots?
        var readFor: LiveShotsMemo.Key?
    }

    init(
        services: any ScreenshotsServices,
        app: StoreApp,
        localizations: [StoreLocale: String],
        locale: StoreLocale,
        primary: StoreLocale,
        width: CGFloat = 78,
        memo: LiveShotsMemo = .shared,
        showsSuggested: Bool = false,
        onPlay: ((_ locale: String, _ displayType: ScreenshotDisplayType) -> Void)? = nil
    ) {
        self.services = services
        self.app = app
        self.localizations = localizations
        self.locale = locale
        self.primary = primary
        self.width = width
        self.memo = memo
        self.showsSuggested = showsSuggested
        self.onPlay = onPlay
        // Seen before in this launch: the first frame shows it.
        let key = LiveShotsMemo.Key(appID: app.id, localizations: localizations)
        if let live = memo.kept(key) {
            _read = State(initialValue: ReadShots(key: key, live: live))
            _strip = State(initialValue: Self.strip(live, locale: locale, primary: primary, services: services, width: width))
        } else {
            _read = State(initialValue: nil)
            _strip = State(initialValue: .reading)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            if strip.isReading {
                PreviewShotsSkeleton(width: width)
            } else {
                rail
                if let caption = strip.caption(overflows: scroll.overflows) {
                    note(caption)
                        .accessibilityHidden(true)
                        .accessibilityIdentifier("storePreview.shots.caption")
                }
            }
            if strip.isBorrowed {
                note(String(localized: "\(LanguageBarModel.shortName(primary)) screenshots until \(LanguageBarModel.shortName(locale)) ones are made"))
            }
        }
        .task(id: key) {
            let key = key
            if let kept = memo.kept(key), read?.key != key {
                read = ReadShots(key: key, live: kept)
            }
            guard memo.needsRead(key) else { return }
            let live = await memo.read(key) { [services, app, localizations] in
                try await services.liveScreenshots(for: app, localizations: localizations)
            }
            guard !Task.isCancelled else { return }
            let fresh = ReadShots(key: key, live: live)
            if read != fresh { read = fresh }
        }
        .task(id: ChosenShots(key: key, locale: locale, read: read?.live, readFor: read?.key)) {
            await loadImages()
        }
        .task(id: SuggestedSource(showsSuggested: showsSuggested, locale: locale, live: read?.live, document: document)) {
            await drawSuggested()
        }
    }

    /// The app's screenshot document: the one a Screenshots view keeps in
    /// step, else the one read here.
    private var document: ScreenshotsDocument? {
        services.documentCenter?.documents[app.id] ?? readDocument
    }

    private var key: LiveShotsMemo.Key {
        LiveShotsMemo.Key(appID: app.id, localizations: localizations)
    }

    /// The App Previews, then every screenshot, left to right in every
    /// language as on the App Store, snapping to each tile; the trailing
    /// edge fades while there's more to scroll to. One element for
    /// VoiceOver, with the play button as its action.
    private var rail: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Spacing.xSmall) {
                ForEach(strip.items) { item in
                    switch item {
                    case let .appPreview(slot):
                        AppPreviewPosterTile(slot: slot, width: width, onPlay: play(slot))
                    case let .screenshot(slot):
                        if let preview = suggestedPreview(for: slot) {
                            suggestedTile(preview)
                        } else {
                            tile(slot)
                        }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.never)
        .onScrollGeometryChange(for: RailScroll.self, of: RailScroll.init) { _, new in scroll = new }
        .mask { fade }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text([strip.accessibilityLabel, suggested.accessibilityText].compactMap(\.self).joined(separator: ", ")))
        .accessibilityValue(Text(strip.appPreviews.first?.accessibilityLabel ?? ""))
        .accessibilityIdentifier("storePreview.shots")
        .modifier(PlayAction(slot: strip.appPreviews.first, play: strip.appPreviews.first.flatMap(play)))
    }

    /// Opaque while everything shows or the end is in view; a fade at the
    /// trailing edge while more waits there.
    @ViewBuilder
    private var fade: some View {
        if scroll.hasMore {
            LinearGradient(
                stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.86), .init(color: .clear, location: 1)],
                startPoint: .leading, endPoint: .trailing
            )
        } else {
            Color.black
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .atlasTextStyle(.subheadline)
            .foregroundStyle(Palette.label2)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func play(_ slot: PreviewAppPreviewSlot) -> (() -> Void)? {
        guard let onPlay else { return nil }
        return { onPlay(slot.locale, slot.displayType) }
    }

    /// The play button as the row's VoiceOver action, when there's one.
    private struct PlayAction: ViewModifier {
        let slot: PreviewAppPreviewSlot?
        let play: (() -> Void)?

        func body(content: Content) -> some View {
            if slot != nil, let play {
                content.accessibilityAction(named: Text("Open the App Preview in Screenshots", comment: "kind:button"), play)
            } else {
                content
            }
        }
    }

    private func tile(_ slot: PreviewShotSlot) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        return ZStack {
            if let image = slot.phase.image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                ImageLoadingTile(isLoading: slot.phase.isLoading, systemImage: slot.isPlaceholder ? nil : "photo")
            }
        }
        .frame(width: width, height: (width * slot.aspect).rounded())
        .clipShape(shape)
        .overlay {
            if slot.phase.image != nil { shape.strokeBorder(Palette.separator2, lineWidth: 0.5) }
        }
        .animation(MotionTiming.fast.animation, value: slot.phase.image != nil)
    }

    /// The screenshot drawn with its suggested caption, with Suggested on.
    private func suggestedPreview(for slot: PreviewShotSlot) -> SlotPreview? {
        guard showsSuggested, !slot.isPlaceholder, let position = strip.slots.firstIndex(where: { $0.id == slot.id }) else { return nil }
        return suggested.preview(at: position)
    }

    /// A suggested caption on its screenshot, in the purple ring of what
    /// the assistant brought.
    private func suggestedTile(_ preview: SlotPreview) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        return SlotPreviewImage(preview: preview, capture: preview.job.capture.flatMap { suggestedCaptures[$0.id] }, width: width)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.aiFill, lineWidth: 2))
            .transition(.opacity)
    }

    /// Lays out the suggested captions on the set the row shows, then
    /// loads the captures they draw.
    private func drawSuggested() async {
        guard showsSuggested, let live = read?.live else {
            suggested = .none
            return
        }
        if document == nil {
            readDocument = try? await services.document(for: app, primaryLocale: primary)
            guard !Task.isCancelled else { return }
        }
        let engine = ScreenshotLayoutEngine(catalog: services.fonts)
        let drawn = SuggestedPreviewShots.make(document: document, live: live, locale: locale, primary: primary, engine: engine)
        if drawn != suggested { suggested = drawn }
        let pixelWidth = Self.pixelWidth(width)
        for preview in drawn.previews.values {
            guard let capture = preview.job.capture, suggestedCaptures[capture.id] == nil else { continue }
            let image = await services.captureImage(capture, for: app, pixelWidth: pixelWidth)
            guard !Task.isCancelled else { return }
            if let image { suggestedCaptures[capture.id] = image }
        }
    }

    /// The chosen language's App Previews and screenshots, all at once;
    /// the ones decoded before show straight away, the others as soon as
    /// each has downloaded, and each App Preview's length once read.
    private func loadImages() async {
        guard let read, read.key == key else {
            strip = .reading
            return
        }
        guard let live = read.live else {
            strip = .unreadable
            return
        }
        strip = Self.strip(live, locale: locale, primary: primary, services: services, width: width)
        let pixelWidth = Self.pixelWidth(width)
        // Every download starts now; each tile fills in, left to right, as
        // soon as its own and the ones before it are here.
        let loads = strip.pending.map { shot in
            (id: shot.id, task: Task { await services.liveImage(shot, pixelWidth: pixelWidth) })
        }
        await withTaskCancellationHandler {
            await loadPosters(pixelWidth: pixelWidth)
            for load in loads {
                let image = await load.task.value
                guard !Task.isCancelled else { return }
                strip.finish(load.id, with: image)
            }
            await loadLengths()
        } onCancel: {
            for load in loads {
                load.task.cancel()
            }
        }
    }

    /// Each App Preview's poster frame, while the screenshots download.
    private func loadPosters(pixelWidth: Int) async {
        for slot in strip.pendingPosters {
            guard let preview = slot.preview else { continue }
            let image = await services.livePreviewPoster(preview, pixelWidth: pixelWidth)
            guard !Task.isCancelled else { return }
            strip.finishPoster(slot.id, with: image)
        }
    }

    /// The length of each App Preview Atlas doesn't know it for, read
    /// from its movie.
    private func loadLengths() async {
        for slot in strip.appPreviews where slot.seconds == nil {
            guard let preview = slot.preview else { continue }
            let seconds = await services.livePreviewSeconds(preview)
            guard !Task.isCancelled else { return }
            strip.setSeconds(seconds, for: slot.id)
        }
    }

    /// The strip `locale` shows from `live`, with every image already
    /// decoded in place.
    private static func strip(
        _ live: LiveScreenshots, locale: StoreLocale, primary: StoreLocale, services: any ScreenshotsServices, width: CGFloat
    ) -> PreviewShotsStrip {
        var strip = PreviewShotsStrip(live: live, locale: locale, primary: primary)
        let pixelWidth = pixelWidth(width)
        strip.finishKept { services.keptLiveImage($0, pixelWidth: pixelWidth) }
        return strip
    }

    private static func pixelWidth(_ width: CGFloat) -> Int {
        Int(width * 3)
    }
}

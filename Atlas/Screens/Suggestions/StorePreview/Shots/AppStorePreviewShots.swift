//
//  AppStorePreviewShots.swift
//  Atlas
//

import CoreGraphics
import SwiftUI

/// The first screenshots people swipe through in a language: what's live on
/// the App Store, from an iPhone set when there is one (`PreviewShotsStrip`).
/// Each tile shows a spinner until its screenshot has downloaded, the
/// screenshots arriving one by one. Shown again, it draws what it read
/// last at once (`LiveShotsMemo`, images decoded before) and reads again
/// behind it only when that's over a minute old. A language without any
/// shows the primary language's, and says so.
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

    /// The app's live screenshots, once read; `live` nil when they
    /// couldn't be.
    @State private var read: ReadShots?
    @State private var strip: PreviewShotsStrip

    private struct ReadShots: Equatable {
        var key: LiveShotsMemo.Key
        var live: LiveScreenshots?
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
        memo: LiveShotsMemo = .shared
    ) {
        self.services = services
        self.app = app
        self.localizations = localizations
        self.locale = locale
        self.primary = primary
        self.width = width
        self.memo = memo
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
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 6) {
                ForEach(strip.slots) { slot in
                    tile(slot)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(strip.accessibilityLabel))
            .accessibilityIdentifier("storePreview.shots")
            if strip.isBorrowed {
                Text("\(LanguageBarModel.shortName(primary)) screenshots until \(LanguageBarModel.shortName(locale)) ones are made")
                    .font(.caption2)
                    .foregroundStyle(Palette.label2)
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
    }

    private var key: LiveShotsMemo.Key {
        LiveShotsMemo.Key(appID: app.id, localizations: localizations)
    }

    private func tile(_ slot: PreviewShotSlot) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
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
        .animation(.easeOut(duration: 0.2), value: slot.phase.image != nil)
    }

    /// The chosen language's screenshots, all at once; the ones decoded
    /// before show straight away, the others as soon as each has
    /// downloaded.
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
            for load in loads {
                let image = await load.task.value
                guard !Task.isCancelled else { return }
                strip.finish(load.id, with: image)
            }
        } onCancel: {
            for load in loads {
                load.task.cancel()
            }
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

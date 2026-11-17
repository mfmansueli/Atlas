//
//  AppStorePreviewShots.swift
//  Atlas
//

import CoreGraphics
import SwiftUI

/// The first screenshots people swipe through in a language: what's live on
/// the App Store, from an iPhone set when there is one (`PreviewShotsStrip`).
/// Each tile shows a spinner until its screenshot has downloaded, the
/// screenshots arriving one by one. A language without any shows the
/// primary language's, and says so.
struct AppStorePreviewShots: View {
    let services: any ScreenshotsServices
    let app: StoreApp
    /// Each language's version localization, where screenshots live.
    let localizations: [StoreLocale: String]
    let locale: StoreLocale
    /// Whose screenshots a language without any shows.
    let primary: StoreLocale
    var width: CGFloat = 78

    /// The app's live screenshots, once read; `live` nil when they
    /// couldn't be.
    @State private var read: ReadShots?
    @State private var strip = PreviewShotsStrip.reading

    private struct ReadShots {
        var appID: String
        var live: LiveScreenshots?
    }

    private struct ChosenShots: Hashable {
        var appID: String
        var locale: StoreLocale
        /// Whose live screenshots are read, so the images load once
        /// they are.
        var readFor: String?
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
        .task(id: app.id) {
            let appID = app.id
            let live = try? await services.liveScreenshots(for: app, localizations: localizations)
            guard !Task.isCancelled else { return }
            read = ReadShots(appID: appID, live: live)
        }
        .task(id: ChosenShots(appID: app.id, locale: locale, readFor: read?.appID)) {
            await loadImages()
        }
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

    /// The chosen language's screenshots, all at once; each shows as soon
    /// as it has downloaded.
    private func loadImages() async {
        guard let read, read.appID == app.id else {
            strip = .reading
            return
        }
        guard let live = read.live else {
            strip = .unreadable
            return
        }
        strip = PreviewShotsStrip(live: live, locale: locale, primary: primary)
        let pixelWidth = Int(width * 3)
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
}

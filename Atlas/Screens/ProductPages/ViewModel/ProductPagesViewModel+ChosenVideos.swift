//
//  ProductPagesViewModel+ChosenVideos.swift
//  Atlas
//

import AVFoundation
import Foundation

// Choose App Previews… (board 51's "Screenshots and App Previews" of a
// page's own): videos the person already has become the page's own App
// Previews in one language on the device shown. Checked like Apple checks
// them, kept on this Mac and queued as one change, in place of a set
// queued before for that language and device. The default page's App
// Previews don't change.
extension ProductPagesViewModel {
    /// The page's own App Previews waiting in Review & Push.
    func queuedAppPreviews(of page: ProductPage, locale: String, device: ProductPageDevice) -> [ProductPageScreenshotsPush.File]? {
        queue.changes(for: app.id, section: .productPages)
            .filter { builder.isAppPreviewsChange($0) && builder.isChange($0, of: page.id) }
            .lazy
            .compactMap { $0.requests.lazy.compactMap(ProductPageScreenshotsPush.init).first?.content }
            .first { $0.locale == locale && device.matches($0.displayType.apiValue) }?
            .files
    }

    /// Reads the videos at `urls` (size, length) and adds them, or says
    /// why not.
    func chooseVideos(_ urls: [URL], for page: ProductPage, locale: String, folder: ProductPageFilesFolder = .shared) async {
        var videos: [ProductPageChosenVideo] = []
        for url in urls {
            let data = (try? Data(contentsOf: url, options: .mappedIfSafe)) ?? Data()
            let facts = await Self.videoFacts(of: url)
            videos.append(ProductPageChosenVideo(fileName: url.lastPathComponent, data: data, pixelSize: facts.size, seconds: facts.seconds))
        }
        addChosenVideos(videos, for: page, locale: locale, folder: folder)
    }

    /// The videos as read: checked, kept and queued.
    func addChosenVideos(_ videos: [ProductPageChosenVideo], for page: ProductPage, locale: String, folder: ProductPageFilesFolder = .shared) {
        guard !videos.isEmpty, canChooseFiles(for: page) else { return }
        let problems = ProductPageVideoCheck.problems(videos, device: device)
        guard problems.isEmpty else {
            filesProblem = ProductPageFilesProblem(pageName: page.name, problems: problems, media: .appPreviews)
            return
        }
        let saved: [ProductPageScreenshotsPush.File]
        do {
            saved = try folder.save(videos, appID: app.id)
        } catch {
            filesProblem = ProductPageFilesProblem(pageName: page.name, problems: [error.localizedDescription], media: .appPreviews)
            return
        }
        let displayType = device.displayType
        defer { pruneChosenFiles(folder: folder) }
        let previewType = ProductPageMedia.appPreviews.setKind(displayType)
        let hadOwn = page.localization(locale)?.previewTypes.contains(previewType) ?? false
        queue.upsert(builder.appPreviewsChange(saved, locale: locale, displayType: displayType, of: page, hadOwn: hadOwn))
        let name = ProductPageChangeBuilder.localeName(locale)
        let text = saved.count == 1
            ? String(localized: "1 App Preview added to “\(page.name)” in \(name). It’s waiting in Review & Push, top right.")
            : String(localized: "\(saved.count) App Previews added to “\(page.name)” in \(name). They’re waiting in Review & Push, top right.")
        toast = ToastMessage(text: text, actionTitle: String(localized: "Review & Push"))
    }

    /// A video's size as it plays (its transform applied) and its length;
    /// nils when it isn't a video Atlas can read.
    nonisolated static func videoFacts(of url: URL) async -> (size: PixelSize?, seconds: Double?) {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (natural, transform) = try? await track.load(.naturalSize, .preferredTransform),
              let duration = try? await asset.load(.duration)
        else { return (nil, nil) }
        let turned = natural.applying(transform)
        let size = PixelSize(width: Int(abs(turned.width).rounded()), height: Int(abs(turned.height).rounded()))
        let seconds = duration.seconds
        return (size, seconds.isFinite ? seconds : nil)
    }
}

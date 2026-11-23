//
//  ProductPagesViewModel+ChosenFiles.swift
//  Atlas
//

import Foundation
import ImageIO

// Choose Files… (board 52's "not drawn"): screenshots the person already
// has become the page's own set in one language on the device shown. They
// are checked like Apple checks them, kept on this Mac and wait in Review
// & Push as one change, in place of a set queued before for that language
// and device. The default page's screenshots don't change.
extension ProductPagesViewModel {
    /// Whether Choose Files… can add screenshots to the page now.
    func canChooseFiles(for page: ProductPage) -> Bool {
        canChange && !isLocked(page)
    }

    /// Reads the files at `urls` and adds them, or says why not.
    func chooseFiles(_ urls: [URL], for page: ProductPage, locale: String, folder: ProductPageFilesFolder = .shared) {
        let files = urls.map { url in
            let data = (try? Data(contentsOf: url)) ?? Data()
            return ProductPageChosenFile(fileName: url.lastPathComponent, data: data, pixelSize: Self.pixelSize(of: data))
        }
        addChosenFiles(files, for: page, locale: locale, folder: folder)
    }

    /// The files as read: checked, kept and queued.
    func addChosenFiles(_ files: [ProductPageChosenFile], for page: ProductPage, locale: String, folder: ProductPageFilesFolder = .shared) {
        guard !files.isEmpty, canChooseFiles(for: page) else { return }
        let problems = ProductPageFileCheck.problems(files, device: device)
        guard problems.isEmpty else {
            filesProblem = ProductPageFilesProblem(pageName: page.name, problems: problems)
            return
        }
        let saved: [ProductPageScreenshotsPush.File]
        do {
            saved = try folder.save(files, appID: app.id)
        } catch {
            let copy = AppleErrorCopy(String(localized: "The screenshots couldn’t be copied.", comment: "kind:error"), error: error)
            filesProblem = ProductPageFilesProblem(pageName: page.name, problems: [copy.text])
            return
        }
        let displayType = device.displayType
        defer { pruneChosenFiles(folder: folder) }
        let hadOwn = page.localization(locale)?.screenshotDisplayTypes.contains(displayType.apiValue) ?? false
        let change = builder.screenshotsChange(saved, locale: locale, displayType: displayType, of: page, hadOwn: hadOwn)
        queue.upsert(change)
        let name = ProductPageChangeBuilder.localeName(locale)
        let text = saved.count == 1
            ? String(localized: "1 screenshot added to “\(page.name)” in \(name). In Review & Push.")
            : String(localized: "\(saved.count) screenshots added to “\(page.name)” in \(name). In Review & Push.")
        toast = ToastMessage(text: text, actionTitle: String(localized: "Review & Push"))
    }

    /// Chosen files no queued change reads any more are deleted (each read
    /// of the pages, and before a new choice).
    func pruneChosenFiles(folder: ProductPageFilesFolder = .shared) {
        let paths = queue.changes(for: app.id, section: .productPages)
            .filter { builder.isScreenshotsChange($0) || builder.isAppPreviewsChange($0) }
            .flatMap { $0.requests.compactMap(ProductPageScreenshotsPush.init) }
            .flatMap(\.content.files)
            .map(\.path)
        folder.prune(appID: app.id, keeping: Set(paths))
    }

    /// The image's size in pixels, nil when it isn't a PNG or JPEG.
    static func pixelSize(of data: Data) -> PixelSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?,
              type == "public.png" || type == "public.jpeg",
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return PixelSize(width: width, height: height)
    }
}

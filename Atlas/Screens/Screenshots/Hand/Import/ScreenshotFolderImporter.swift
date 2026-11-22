//
//  ScreenshotFolderImporter.swift
//  Atlas
//

import Foundation

/// Reads a folder of screenshots for several languages and devices, as
/// fastlane's `screenshots/` lays them out and as Atlas exports them: the
/// language from a folder named by its code (`de-DE`, `ja`), the device
/// from the folder or file name (`iphone-6.9`, `ipad-13`, `mac`,
/// `APP_IPHONE_67`) or else the image's size, the order from the leading
/// number in the file name. Nothing is scaled: files of a wrong size are
/// skipped with the reason.
struct ScreenshotFolderImporter {
    /// The languages on the app's store page.
    let pageLocales: [StoreLocale]
    let appName: String

    struct Found: Hashable {
        var path: [String]
        var file: ScreenshotHandChosenFile
    }

    /// Every PNG and JPEG under `root`, read.
    static func files(in root: URL) -> [Found] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }
        let rootComponents = root.standardizedFileURL.pathComponents
        var found: [Found] = []
        for case let url as URL in enumerator {
            guard ["png", "jpg", "jpeg"].contains(url.pathExtension.lowercased()),
                  (try? url.resourceValues(forKeys: Set(keys)))?.isRegularFile == true else { continue }
            let path = Array(url.standardizedFileURL.pathComponents.dropFirst(rootComponents.count))
            found.append(Found(path: path, file: ScreenshotHandChosenFile(url: url)))
        }
        return found
    }

    func rows(in root: URL) -> [ScreenshotFolderImportRow] {
        rows(for: Self.files(in: root))
    }

    /// Groups the files by language and device, in order.
    func rows(for found: [Found]) -> [ScreenshotFolderImportRow] {
        var groups: [String: Group] = [:]
        var order: [String] = []
        for item in found {
            let folders = Array(item.path.dropLast())
            let match = languageFolder(in: folders)
            let display = Self.device(in: folders + [item.file.fileName]) ?? item.file.pixelSize.flatMap(Self.device(of:))
            let folder = match?.folder ?? folders.first ?? item.file.fileName
            let key = "\(folder)|\(display?.rawValue ?? "-")"
            if groups[key] == nil {
                order.append(key)
                groups[key] = Group(folder: folder, locale: match?.page, known: match?.known, display: display)
            }
            groups[key]?.files.append(item)
        }
        return order.compactMap { key in
            guard let group = groups[key] else { return nil }
            return row(folder: group.folder, page: group.locale, known: group.known, display: group.display, files: group.files)
        }
        .sorted { lhs, rhs in
            let left = pageLocales.firstIndex { $0.code == lhs.localeCode } ?? .max
            let right = pageLocales.firstIndex { $0.code == rhs.localeCode } ?? .max
            if left != right { return left < right }
            return (lhs.displayType.map(Self.order) ?? .max) < (rhs.displayType.map(Self.order) ?? .max)
        }
    }

    /// The files of one language folder on one device.
    private struct Group {
        var folder: String
        var locale: StoreLocale?
        var known: StoreLocale?
        var display: ScreenshotDisplayType?
        var files: [Found] = []
    }

    private func row(
        folder: String,
        page: StoreLocale?,
        known: StoreLocale?,
        display: ScreenshotDisplayType?,
        files: [Found]
    ) -> ScreenshotFolderImportRow {
        let name = page?.name ?? folder
        func skipped(_ problem: String) -> ScreenshotFolderImportRow {
            ScreenshotFolderImportRow(
                folderName: folder, localeCode: page?.code, languageName: name, displayType: display, files: [], skippedFiles: [], problem: problem
            )
        }
        guard let page else {
            if let known {
                return skipped(String(localized: "Skipped: \(known.name) isn’t on \(appName)’s App Store page. Add it in Store Page first."))
            }
            return skipped(String(localized: "Skipped: “\(folder)” isn’t a language folder. Name it by its code, like de-DE or ja."))
        }
        guard let display else {
            return skipped(String(localized: "Skipped: Atlas can’t tell the device. Put it in the folder or file name, like iphone-6.9 or ipad-13."))
        }
        let sorted = files.sorted { Self.orderKey($0.file.fileName) < Self.orderKey($1.file.fileName) }
        var fitting: [ScreenshotHandChosenFile] = []
        var skippedFiles: [String] = []
        var firstProblem: String?
        for item in sorted {
            let check = ScreenshotHandFileCheck(item.file, on: display)
            if check.fits, fitting.count < ScreenshotHandSet.capacity {
                fitting.append(item.file)
            } else if check.fits {
                skippedFiles.append(String(localized: "\(item.file.fileName): over 10"))
            } else {
                skippedFiles.append("\(item.file.fileName): \(check.shortTitle)")
                if firstProblem == nil, case let .wrongSize(size) = check {
                    firstProblem = String(localized: "Skipped: \(size.title) isn’t an \(display.title) size.")
                }
                if firstProblem == nil { firstProblem = check.problem(fileName: item.file.fileName, on: display) }
            }
        }
        guard !fitting.isEmpty else { return skipped(firstProblem ?? String(localized: "Skipped: no images that fit.")) }
        return ScreenshotFolderImportRow(
            folderName: folder, localeCode: page.code, languageName: page.name, displayType: display, files: fitting,
            skippedFiles: skippedFiles, problem: nil
        )
    }

    // MARK: - Matching

    /// The innermost folder named like a language, and the page's locale it
    /// is (or the catalog's, when the page doesn't have it).
    private func languageFolder(in folders: [String]) -> (folder: String, page: StoreLocale?, known: StoreLocale?)? {
        for folder in folders.reversed() {
            let code = folder.replacingOccurrences(of: "_", with: "-")
            if let page = pageLocales.first(where: { $0.code.caseInsensitiveCompare(code) == .orderedSame }) {
                return (folder, page, page)
            }
            // "de" for "de-DE" when the page has only one German.
            let language = pageLocales.filter { $0.code.lowercased().hasPrefix(code.lowercased() + "-") }
            if language.count == 1, code.count <= 3 { return (folder, language[0], language[0]) }
            if let known = StoreLocaleCatalog.locale(code: code) { return (folder, nil, known) }
        }
        return nil
    }

    /// The device a folder or file name says: `iphone-6.9`, `ipad-13`,
    /// `mac`, `watch`, `vision`, fastlane's `APP_IPHONE_67`.
    static func device(in names: [String]) -> ScreenshotDisplayType? {
        for name in names.reversed() {
            let lower = name.lowercased()
            if lower.contains("duo") { return .iPhoneDuo }
            if lower.contains("ipad") { return .iPad }
            if lower.contains("iphone") { return .iPhone }
            if lower.contains("watch") { return .watch }
            if lower.contains("vision") { return .visionPro }
            let words = lower.split { !$0.isLetter && !$0.isNumber }
            if words.contains("mac") || words.contains("desktop") || words.contains("macos") { return .mac }
        }
        return nil
    }

    /// The device an image's size is for; iPhone before the others.
    static func device(of size: PixelSize) -> ScreenshotDisplayType? {
        [.iPhone, .iPad, .mac, .watch, .visionPro, .iPhoneDuo].first { ScreenshotHandSizes.accepts(size, on: $0) }
    }

    /// The leading number first ("01.png", "2_home.png"), then the name.
    static func orderKey(_ fileName: String) -> String {
        let digits = fileName.prefix { $0.isNumber }
        let number = Int(digits) ?? Int.max
        return String(format: "%010d|", min(number, 999_999_999)) + fileName.lowercased()
    }

    private static func order(_ display: ScreenshotDisplayType) -> Int {
        ScreenshotDisplayType.studio.firstIndex(of: display) ?? .max
    }
}

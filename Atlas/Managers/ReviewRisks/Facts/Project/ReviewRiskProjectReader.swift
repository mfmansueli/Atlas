//
//  ReviewRiskProjectReader.swift
//  Atlas
//

import Foundation

/// Reads an app's project folder for the App Review checks, without
/// building it: dependencies, imports, entitlements, permission texts and
/// their languages, and what the Swift code does with accounts and
/// permissions. It skips what isn't the app's own code (Pods, Carthage,
/// build products, node_modules, test folders), files over 1 MB, and Swift
/// files past the first 4,000.
enum ReviewRiskProjectReader {
    static let swiftFileLimit = 4000
    static let fileSizeLimit = 1_000_000
    /// project.pbxproj and string catalogs grow past 1 MB in big projects.
    static let largeFileSizeLimit = 5_000_000
    static let skippedFolders: Set<String> = [
        "Pods", "Carthage", "DerivedData", "node_modules", "build", "Build", "SourcePackages", "checkouts", "vendor", "Vendor",
    ]
    /// Packages whose insides are build products or assets, not code.
    static let skippedExtensions: Set<String> = [
        "xcassets", "xcframework", "framework", "bundle", "app", "appex", "xcarchive", "dSYM", "docc", "xcdatamodeld",
        "scnassets", "playground", "xcresult",
    ]

    /// What `folder` shows; nil when it can't be opened.
    static func read(folder: URL, fileManager: FileManager = .default) -> ReviewRiskProjectFacts? {
        let root = folder.standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = root.path(percentEncoded: false)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootPath, isDirectory: &isDirectory), isDirectory.boolValue,
              let enumerator = fileManager.enumerator(
                  at: root, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles]
              )
        else { return nil }

        var facts = ReviewRiskProjectFacts(folderName: folder.lastPathComponent)
        let found = walk(enumerator, into: &facts)
        for url in found.resolvedFiles {
            guard let data = try? Data(contentsOf: url) else { continue }
            facts.packages.formUnion(ReviewRiskPackageReader.packageResolved(data))
        }
        var languages = found.lprojLanguages
        var development = readProjects(found.projects, rootPath: rootPath, languages: &languages, into: &facts)
        readInfoPlists(found.infoPlists, rootPath: rootPath, into: &facts)
        readEntitlements(found.entitlementFiles, into: &facts)
        let catalogSource = readTranslations(found, languages: &languages, into: &facts)
        if development == nil { development = catalogSource }
        facts.languages = languages
        facts.developmentLanguage = ReviewRiskLanguageCode.base(development ?? "en")
        readSwift(found.swiftFiles, rootPath: rootPath, into: &facts)
        return facts
    }

    /// The files a walk of the folder found, by what Atlas reads in them.
    private struct Found {
        var swiftFiles: [URL] = []
        var projects: [URL] = []
        var resolvedFiles: [URL] = []
        var infoPlists: [URL] = []
        var entitlementFiles: [URL] = []
        var catalogs: [URL] = []
        var stringsFiles: [(language: String, url: URL)] = []
        var lprojLanguages: Set<String> = []
    }

    /// Walks the folder, skipping what doesn't ship; Podfile.lock and
    /// Cartfile.resolved are read on the way.
    private static func walk(_ enumerator: FileManager.DirectoryEnumerator, into facts: inout ReviewRiskProjectFacts) -> Found {
        var found = Found()
        while let url = enumerator.nextObject() as? URL {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if values?.isDirectory == true {
                if folder(url, into: &found) { enumerator.skipDescendants() }
            } else {
                file(url, size: values?.fileSize ?? 0, into: &found, facts: &facts)
            }
        }
        return found
    }

    /// Notes a folder; true when its insides aren't read.
    private static func folder(_ url: URL, into found: inout Found) -> Bool {
        let name = url.lastPathComponent
        if skippedFolders.contains(name) || isTestFolder(name) || skippedExtensions.contains(url.pathExtension) { return true }
        switch url.pathExtension {
        case "xcodeproj":
            found.projects.append(url)
            found.resolvedFiles.append(url.appending(path: "project.xcworkspace/xcshareddata/swiftpm/Package.resolved"))
            return true
        case "xcworkspace":
            found.resolvedFiles.append(url.appending(path: "xcshareddata/swiftpm/Package.resolved"))
            return true
        case "lproj" where name.lowercased() != "base.lproj":
            found.lprojLanguages.insert(ReviewRiskLanguageCode.base(url.deletingPathExtension().lastPathComponent))
            return false
        default:
            return false
        }
    }

    private static func file(_ url: URL, size: Int, into found: inout Found, facts: inout ReviewRiskProjectFacts) {
        let name = url.lastPathComponent
        switch url.pathExtension {
        case "swift" where size <= fileSizeLimit: found.swiftFiles.append(url)
        case "plist" where name.contains("Info") && name != "GoogleService-Info.plist" && size <= fileSizeLimit: found.infoPlists.append(url)
        case "entitlements" where size <= fileSizeLimit: found.entitlementFiles.append(url)
        case "xcstrings" where size <= largeFileSizeLimit: found.catalogs.append(url)
        case "strings" where name == "InfoPlist.strings" && url.deletingLastPathComponent().pathExtension == "lproj":
            let language = url.deletingLastPathComponent().deletingPathExtension().lastPathComponent
            if language.lowercased() != "base" { found.stringsFiles.append((ReviewRiskLanguageCode.base(language), url)) }
        default:
            readLockFile(url, name: name, into: &found, facts: &facts)
        }
    }

    /// Package.resolved waits for the others; Podfile.lock and
    /// Cartfile.resolved are read now.
    private static func readLockFile(_ url: URL, name: String, into found: inout Found, facts: inout ReviewRiskProjectFacts) {
        switch name {
        case "Package.resolved":
            found.resolvedFiles.append(url)
        case "Podfile.lock":
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            facts.packages.formUnion(ReviewRiskPackageReader.podfileLock(text))
        case "Cartfile.resolved":
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            facts.packages.formUnion(ReviewRiskPackageReader.cartfileResolved(text))
        default:
            return
        }
    }

    /// Permission texts set as build settings, and the regions; the
    /// development region of the first project that names one.
    private static func readProjects(
        _ projects: [URL], rootPath: String, languages: inout Set<String>, into facts: inout ReviewRiskProjectFacts
    ) -> String? {
        var development: String?
        for project in projects.sorted(by: { $0.path < $1.path }) {
            let pbxproj = project.appending(path: "project.pbxproj")
            guard fileSize(pbxproj) <= largeFileSizeLimit, let text = try? String(contentsOf: pbxproj, encoding: .utf8) else { continue }
            for purpose in ReviewRiskPurposeStringReader.buildSettings(text, file: relativePath(pbxproj, root: rootPath)) {
                merge(purpose, into: &facts)
            }
            let regions = ReviewRiskPurposeStringReader.regions(text)
            languages.formUnion(regions.known)
            if development == nil { development = regions.development }
        }
        return development
    }

    private static func readInfoPlists(_ urls: [URL], rootPath: String, into facts: inout ReviewRiskProjectFacts) {
        for url in urls.sorted(by: { $0.path < $1.path }) {
            guard let data = try? Data(contentsOf: url) else { continue }
            for purpose in ReviewRiskPurposeStringReader.infoPlist(data, file: relativePath(url, root: rootPath)) {
                merge(purpose, into: &facts)
            }
        }
    }

    private static func readEntitlements(_ urls: [URL], into facts: inout ReviewRiskProjectFacts) {
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            else { continue }
            facts.entitlements.formUnion(plist.keys)
        }
    }

    /// InfoPlist catalogs and strings files, and every catalog's languages;
    /// the first catalog's source language.
    private static func readTranslations(_ found: Found, languages: inout Set<String>, into facts: inout ReviewRiskProjectFacts) -> String? {
        var translations: [String: Set<String>] = [:]
        var source: String?
        for url in found.catalogs {
            guard let data = try? Data(contentsOf: url) else { continue }
            let catalog = ReviewRiskPurposeStringReader.stringCatalog(data)
            languages.formUnion(catalog.languages)
            if source == nil { source = catalog.source }
            guard url.lastPathComponent == "InfoPlist.xcstrings" else { continue }
            for (key, bases) in catalog.keys { translations[key, default: []].formUnion(bases) }
        }
        for (language, url) in found.stringsFiles {
            guard let data = try? Data(contentsOf: url) else { continue }
            for key in ReviewRiskPurposeStringReader.stringsFile(data) { translations[key, default: []].insert(language) }
        }
        for (key, bases) in translations { facts.purposeStrings[key]?.languages.formUnion(bases) }
        return source
    }

    private static func readSwift(_ urls: [URL], rootPath: String, into facts: inout ReviewRiskProjectFacts) {
        let sorted = urls.sorted { $0.path < $1.path }
        facts.reachedFileLimit = sorted.count > swiftFileLimit
        for url in sorted.prefix(swiftFileLimit) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            facts.swiftFileCount += 1
            ReviewRiskSourceScanner.scan(text, file: relativePath(url, root: rootPath), into: &facts)
        }
    }

    /// "AlbaTests", "AlbaUITests", "Tests": test targets don't ship.
    static func isTestFolder(_ name: String) -> Bool {
        name == "Tests" || name.hasSuffix("Tests")
    }

    /// The path under the project folder: "Alba/Info.plist".
    static func relativePath(_ url: URL, root: String) -> String {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : url.lastPathComponent
    }

    /// The first written text for a key wins; an empty one gives way.
    private static func merge(_ purpose: ReviewRiskPurposeString, into facts: inout ReviewRiskProjectFacts) {
        if let existing = facts.purposeStrings[purpose.key], existing.isWritten || !purpose.isWritten { return }
        facts.purposeStrings[purpose.key] = purpose
    }

    private static func fileSize(_ url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }
}

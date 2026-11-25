//
//  ReviewRiskProjectFixtures.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Facts, code matches and temporary project folders for the project
/// checks' tests.
enum ReviewRiskProjectFixtures {
    static func facts(_ project: ReviewRiskProjectFacts?, texts: ReviewRiskTextFacts? = nil) -> ReviewRiskFacts {
        var facts = ReviewRiskFacts(
            appID: "6450000001", appName: "Lumen Journal", bundleID: "com.northpier.lumen", now: Date(timeIntervalSince1970: 1_800_000_000)
        )
        facts.project = project
        facts.texts = texts
        return facts
    }

    /// A project with Swift files read and nothing found yet.
    static func project(swiftFiles: Int = 12) -> ReviewRiskProjectFacts {
        var project = ReviewRiskProjectFacts(folderName: "Lumen")
        project.swiftFileCount = swiftFiles
        return project
    }

    /// The project after reading `source` as one Swift file.
    static func scanned(_ source: String, file: String = "Lumen/Source.swift") -> ReviewRiskProjectFacts {
        var project = project()
        ReviewRiskSourceScanner.scan(source, file: file, into: &project)
        return project
    }

    static func match(_ what: String, file: String = "Lumen/Account/AccountView.swift", line: Int = 10, excerpt: String = "code") -> ReviewRiskCodeMatch {
        ReviewRiskCodeMatch(what: what, file: file, line: line, excerpt: excerpt)
    }

    /// Store texts in `locales`, the first primary.
    static func texts(_ locales: [String]) -> ReviewRiskTextFacts {
        ReviewRiskTextFacts(
            texts: locales.map { locale in
                ReviewRiskText(
                    place: .storeListing, field: .description, label: "Description", locale: locale, text: "A journal.",
                    key: "storeListing.description.\(locale)"
                )
            },
            primaryLocale: locales.first ?? "en-US"
        )
    }

    // MARK: - Folders

    /// A new empty folder; the test removes it.
    static func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "ReviewRiskProject-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func write(_ text: String, to path: String, in folder: URL) throws {
        let url = folder.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func remove(_ folder: URL) {
        try? FileManager.default.removeItem(at: folder)
    }
}

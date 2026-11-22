//
//  ProjectFolderVerdictTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Connect's first step: the folder given holds the app's Xcode project,
/// or the step says what's missing.
@Suite("ProjectFolderVerdict")
struct ProjectFolderVerdictTests {
    private let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "verdict-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    /// `<folder>/<name>.xcodeproj/project.pbxproj` setting `bundleIDs`.
    @discardableResult
    private func project(_ name: String, in folder: String, bundleIDs: [String]) throws -> URL {
        let project = root.appending(path: folder).appending(path: "\(name).xcodeproj", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let lines = bundleIDs.map { "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"\($0)\";" }.joined(separator: "\n")
        try Data(lines.utf8).write(to: project.appending(path: "project.pbxproj"))
        return project
    }

    private func folder(_ name: String) throws -> URL {
        let url = root.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func theAppsProjectMatches() throws {
        try project("Lumen", in: "Lumen", bundleIDs: ["dev.northpier.lumen", "dev.northpier.lumen.widget"])
        let verdict = try ProjectFolderVerdict.check(folder("Lumen"), bundleID: "dev.northpier.lumen")
        #expect(verdict.outcome == .matches(project: "Lumen.xcodeproj"))
        #expect(verdict.isAccepted)
        #expect(verdict.folderName == "Lumen")
    }

    @Test func aProjectTwoFoldersDownCounts() throws {
        try project("Lumen", in: "Repo/apps/ios", bundleIDs: ["dev.northpier.lumen"])
        let verdict = try ProjectFolderVerdict.check(folder("Repo"), bundleID: "dev.northpier.lumen")
        #expect(verdict.outcome == .matches(project: "Lumen.xcodeproj"))
    }

    @Test func aFolderWithoutAProjectSaysSo() throws {
        let verdict = try ProjectFolderVerdict.check(folder("Downloads"), bundleID: "dev.northpier.lumen")
        #expect(verdict.outcome == .noProject)
        #expect(!verdict.isAccepted)
    }

    @Test func anotherAppsProjectIsNamed() throws {
        try project("Bruma", in: "Bruma", bundleIDs: ["com.lima.bruma", "com.lima.bruma.widget"])
        let verdict = try ProjectFolderVerdict.check(folder("Bruma"), bundleID: "dev.northpier.lumen")
        #expect(verdict.outcome == .otherApp(project: "Bruma.xcodeproj", bundleIDs: ["com.lima.bruma"]))
        #expect(!verdict.isAccepted)
    }

    @Test func aBundleIDFromASettingIsTakenAsTheApps() throws {
        try project("Lumen", in: "Lumen", bundleIDs: ["$(BASE_ID).app"])
        let verdict = try ProjectFolderVerdict.check(folder("Lumen"), bundleID: "dev.northpier.lumen")
        #expect(verdict.outcome == .unchecked(project: "Lumen.xcodeproj"))
        #expect(verdict.isAccepted)
    }

    /// Dragged from the title of Xcode's window: the folder around it.
    @Test func aDroppedProjectStandsForItsFolder() throws {
        let dropped = try project("Lumen", in: "Lumen", bundleIDs: ["dev.northpier.lumen"])
        let verdict = ProjectFolderVerdict.check(dropped, bundleID: "dev.northpier.lumen")
        #expect(verdict.outcome == .matches(project: "Lumen.xcodeproj"))
        #expect(verdict.folderName == "Lumen")
        #expect(!verdict.folder.hasSuffix("/"))
    }

    @Test func aFolderAtlasCantReadIsUnreadable() {
        let verdict = ProjectFolderVerdict.check(root.appending(path: "missing", directoryHint: .isDirectory), bundleID: "dev.northpier.lumen")
        #expect(verdict.outcome == .unreadable)
    }

    @Test func withoutABundleIDAnyProjectIsTaken() throws {
        try project("Lumen", in: "Lumen", bundleIDs: ["com.other"])
        let verdict = try ProjectFolderVerdict.check(folder("Lumen"), bundleID: nil)
        #expect(verdict.outcome == .matches(project: "Lumen.xcodeproj"))
    }

    // MARK: - The suggestion

    @Test func theSuggestionIsTheFirstFolderWithTheApp() throws {
        try project("Bruma", in: "Bruma", bundleIDs: ["com.lima.bruma"])
        try project("Lumen", in: "Lumen", bundleIDs: ["dev.northpier.lumen"])
        let candidates = [
            AssistantFolderSuggestion.Candidate(folder: root.appending(path: "Bruma").path(percentEncoded: false), source: "Cursor worked here"),
            AssistantFolderSuggestion.Candidate(folder: root.appending(path: "Lumen").path(percentEncoded: false), source: "Claude Code worked here"),
        ]
        let suggestion = try #require(AssistantFolderSuggestion.first(of: candidates, bundleID: "dev.northpier.lumen"))
        #expect(suggestion.folderName == "Lumen")
        #expect(suggestion.detail == "Lumen.xcodeproj · Claude Code worked here")
    }

    @Test func aFolderAtlasCantReadYetIsStillOffered() {
        let missing = root.appending(path: "Elsewhere").path(percentEncoded: false)
        let suggestion = AssistantFolderSuggestion.first(of: [.init(folder: missing, source: "Claude Code worked here")], bundleID: "x")
        #expect(suggestion?.folder == missing)
        #expect(suggestion?.projectName == nil)
    }

    @Test func noSuggestionWithoutTheApp() throws {
        try project("Bruma", in: "Bruma", bundleIDs: ["com.lima.bruma"])
        let candidates = [AssistantFolderSuggestion.Candidate(folder: root.appending(path: "Bruma").path(percentEncoded: false), source: "")]
        #expect(AssistantFolderSuggestion.first(of: candidates, bundleID: "dev.northpier.lumen") == nil)
    }
}

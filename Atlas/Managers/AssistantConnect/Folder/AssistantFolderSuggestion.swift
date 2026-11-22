//
//  AssistantFolderSuggestion.swift
//  Atlas
//

import Foundation

/// The folder Connect offers with Use This Folder: one Atlas already
/// knows for the app (given to this assistant before, Claude Code's
/// folder for the app) or one an assistant worked in, when it holds the
/// app's project. Atlas can't read Xcode's own list of recent projects
/// from the sandbox, so these are the folders it has seen.
struct AssistantFolderSuggestion: Hashable, Sendable {
    /// Absolute path.
    var folder: String
    /// "Lumen.xcodeproj", when Atlas could look inside.
    var projectName: String?
    /// Where Atlas knows it from: "Claude Code worked here".
    var source: String

    var folderName: String {
        URL(filePath: folder, directoryHint: .isDirectory).lastPathComponent
    }

    /// "Lumen.xcodeproj · Claude Code worked here".
    var detail: String {
        [projectName, source].compactMap { $0 }.joined(separator: " · ")
    }

    /// A candidate folder and where it came from.
    struct Candidate: Hashable, Sendable {
        var folder: String
        var source: String
    }

    /// The first candidate that holds `bundleID`'s project, or that Atlas
    /// can't look inside yet (asked about when it's used); never one that
    /// plainly builds another app or has no project.
    static func first(
        of candidates: [Candidate],
        bundleID: String?,
        check: (URL, String?) -> ProjectFolderVerdict = { ProjectFolderVerdict.check($0, bundleID: $1) }
    ) -> AssistantFolderSuggestion? {
        var seen: Set<String> = []
        var unreadable: AssistantFolderSuggestion?
        for candidate in candidates {
            let folder = ProjectFolderPath.expanded(candidate.folder)
            guard seen.insert(folder).inserted else { continue }
            let verdict = check(URL(filePath: folder, directoryHint: .isDirectory), bundleID)
            switch verdict.outcome {
            case .matches, .unchecked:
                return AssistantFolderSuggestion(folder: verdict.folder, projectName: verdict.projectName, source: candidate.source)
            case .unreadable:
                if unreadable == nil { unreadable = AssistantFolderSuggestion(folder: folder, projectName: nil, source: candidate.source) }
            case .noProject, .otherApp:
                continue
            }
        }
        return unreadable
    }
}

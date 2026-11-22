//
//  ProjectFolderVerdict.swift
//  Atlas
//

import Foundation

/// What Connect's first step found in the folder the person gave: the
/// app's Xcode project with this app's bundle ID, or what's missing. A
/// project dragged from the title of Xcode's window stands for the folder
/// around it.
struct ProjectFolderVerdict: Hashable, Sendable {
    enum Outcome: Hashable, Sendable {
        /// `project` builds the app.
        case matches(project: String)
        /// A project whose bundle ID comes from a build setting, so it
        /// can't be compared; taken as the app's.
        case unchecked(project: String)
        /// No Xcode project in the folder or two folders below it.
        case noProject
        /// Its projects build other apps.
        case otherApp(project: String, bundleIDs: [String])
        /// The sandbox doesn't let Atlas look inside yet.
        case unreadable
    }

    /// Absolute path of the folder.
    var folder: String
    var outcome: Outcome

    /// Whether Connect may go on with it.
    var isAccepted: Bool {
        switch outcome {
        case .matches, .unchecked: true
        case .noProject, .otherApp, .unreadable: false
        }
    }

    var projectName: String? {
        switch outcome {
        case let .matches(project), let .unchecked(project), let .otherApp(project, _): project
        case .noProject, .unreadable: nil
        }
    }

    /// "Lumen", the folder's own name.
    var folderName: String {
        URL(filePath: folder, directoryHint: .isDirectory).lastPathComponent
    }

    /// Reads `url` (a folder, or an `.xcodeproj`/`.xcworkspace` inside
    /// one) for `bundleID`'s project. Without a bundle ID any project is
    /// taken.
    static func check(_ url: URL, bundleID: String?, fileManager: FileManager = .default) -> ProjectFolderVerdict {
        let isProjectFile = ["xcodeproj", "xcworkspace"].contains(url.pathExtension)
        let folderURL = isProjectFile ? url.deletingLastPathComponent() : url
        let folder = folderURL.standardizedFileURL.path(percentEncoded: false)
        let trimmed = folder.count > 1 && folder.hasSuffix("/") ? String(folder.dropLast()) : folder
        let projects: [URL]
        if url.pathExtension == "xcodeproj" {
            projects = [url]
        } else if url.pathExtension == "xcworkspace" {
            projects = ProjectFolderCheck.projects(in: folderURL, depth: 0, fileManager: fileManager)
        } else {
            guard (try? fileManager.contentsOfDirectory(atPath: url.path(percentEncoded: false))) != nil else {
                return ProjectFolderVerdict(folder: trimmed, outcome: .unreadable)
            }
            projects = ProjectFolderCheck.projects(in: url, depth: 2, fileManager: fileManager)
        }
        return ProjectFolderVerdict(folder: trimmed, outcome: outcome(of: projects, bundleID: bundleID))
    }

    private static func outcome(of projects: [URL], bundleID: String?) -> Outcome {
        let sorted = projects.sorted { $0.path(percentEncoded: false).count < $1.path(percentEncoded: false).count }
        guard let first = sorted.first else { return .noProject }
        guard let bundleID else { return .matches(project: first.lastPathComponent) }
        var found: Set<String> = []
        var withVariables: URL?
        for project in sorted {
            let text = (try? String(contentsOf: project.appending(path: "project.pbxproj"), encoding: .utf8)) ?? ""
            let ids = ProjectFolderCheck.bundleIDs(inProjectFile: text)
            if ids.contains(bundleID) { return .matches(project: project.lastPathComponent) }
            if ids.contains(where: { $0.contains("$") }), withVariables == nil { withVariables = project }
            found.formUnion(ids.filter { !$0.contains("$") })
        }
        if let withVariables { return .unchecked(project: withVariables.lastPathComponent) }
        // Nothing readable to compare isn't held against the person.
        if found.isEmpty { return .unchecked(project: first.lastPathComponent) }
        let apps = ProjectFolderCheck(bundleIDs: found.sorted(), hasVariables: false).appBundleIDs
        return .otherApp(project: first.lastPathComponent, bundleIDs: apps)
    }
}

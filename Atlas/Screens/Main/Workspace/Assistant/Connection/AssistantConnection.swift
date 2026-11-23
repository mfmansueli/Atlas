//
//  AssistantConnection.swift
//  Atlas
//

import Foundation

/// What the overview's assistant card and the Assistant popover say about
/// the person's own assistant for the app on screen. One local server
/// serves every app; what differs per app is its project folder, so this
/// compares the folders open sessions work in (their MCP roots) with the
/// app's own (`ClaudeCodeLauncher.projectFolder(for:)`), and says so when
/// Atlas turned a request away for a token it doesn't know. Before,
/// the card said "Claude Code is connected · Project ~/Projects/ios/Alba"
/// on SimProps while SimProps's Claude Code was refused.
struct AssistantConnection: Hashable, Sendable {
    enum State: Hashable, Sendable {
        /// A session works in the app's project folder, or inside it.
        case connectedHere(folder: String)
        /// Sessions are open, none in the app's folder: the first one's
        /// folder, and the app it was given to, if any.
        case connectedElsewhere(folder: String, appName: String?)
        /// Sessions are open and the app has no folder yet: where one works
        /// (nil when none said), which may or may not be the app's.
        case connectedUnsure(folder: String?)
        /// A request came with a token that matches no pairing since the
        /// last good connection; `client` when it said who it was.
        case refused(date: Date, client: String?)
        /// Nothing is connected; Atlas starts Claude Code itself.
        case readyToStart
        /// Nothing is connected, and Atlas can't start it.
        case notConnected(lastSeen: Date?)
    }

    enum Action: Hashable, Sendable {
        /// Reconnect…: the setup sheet, for a new command.
        case reconnect
        /// Choose Folder…: the app's project folder.
        case chooseFolder
    }

    /// The status dot: green, yellow or red, never alone (the title says
    /// it too).
    enum Tone: Hashable, Sendable {
        case good
        case attention
        case problem
    }

    /// e.g. "Claude Code".
    let clientName: String
    let appName: String
    /// The app's project folder, e.g. "~/Projects/ios/SimProps", once
    /// chosen.
    let appFolder: String?
    let state: State
    let editsDrafts: Bool
    /// The assistant's latest request, for "last call 2 min ago".
    let lastCall: Date?
    /// Atlas starts Claude Code itself when asked (its helper is
    /// installed), so Suggest Everything… works with nothing connected.
    let startsRuns: Bool

    init(
        clientName: String,
        appName: String,
        appFolder: String?,
        state: State,
        editsDrafts: Bool = false,
        lastCall: Date? = nil,
        startsRuns: Bool = false
    ) {
        self.clientName = clientName
        self.appName = appName
        self.appFolder = appFolder
        self.state = state
        self.editsDrafts = editsDrafts
        self.lastCall = lastCall
        self.startsRuns = startsRuns
    }

    /// Works out the state from what the server knows. Folders are written
    /// the same way throughout, "~/Projects/ios/Alba".
    /// - Parameters:
    ///   - sessionFolders: one per open session, nil when it didn't say.
    ///   - otherApps: the folders other apps were given, with their names.
    static func state(
        appFolder: String?,
        sessionFolders: [String?],
        otherApps: [(folder: String, appName: String?)],
        refused: MCPRefusedConnection?,
        canStart: Bool,
        lastSeen: Date?
    ) -> State {
        let folders = sessionFolders.compactMap(\.self)
        if let appFolder, let here = folders.first(where: { isInside($0, appFolder) }) { return .connectedHere(folder: here) }
        if let refused { return .refused(date: refused.date, client: refused.clientName) }
        guard !sessionFolders.isEmpty else { return canStart ? .readyToStart : .notConnected(lastSeen: lastSeen) }
        for folder in folders {
            if let other = otherApps.first(where: { isInside(folder, $0.folder) }) {
                return .connectedElsewhere(folder: folder, appName: other.appName)
            }
        }
        guard let folder = folders.first, appFolder != nil else { return .connectedUnsure(folder: folders.first) }
        return .connectedElsewhere(folder: folder, appName: nil)
    }

    /// `folder` is `parent` or inside it.
    static func isInside(_ folder: String, _ parent: String) -> Bool {
        let folder = trimmed(folder)
        let parent = trimmed(parent)
        return folder == parent || folder.hasPrefix(parent + "/")
    }

    private static func trimmed(_ path: String) -> String {
        path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    // MARK: - What it says

    /// "Claude Code is connected", "… is connected to another project",
    /// "… can’t connect", "… is ready", "… isn’t connected".
    var title: String {
        switch state {
        case .connectedHere, .connectedUnsure: String(localized: "\(clientName) is connected")
        case .connectedElsewhere: String(localized: "\(clientName) is connected to another project")
        case let .refused(_, client): String(localized: "\(client ?? clientName) can’t connect")
        case .readyToStart: String(localized: "\(clientName) is ready")
        case .notConnected: String(localized: "\(clientName) isn’t connected")
        }
    }

    /// The popover's status: "Connected", "Another project", "Can’t
    /// connect", "Ready", "Not connected".
    var statusTitle: String {
        switch state {
        case .connectedHere, .connectedUnsure: String(localized: "Connected")
        case .connectedElsewhere: String(localized: "Another project")
        case .refused: String(localized: "Can’t connect")
        case .readyToStart: String(localized: "Ready")
        case .notConnected: String(localized: "Not connected")
        }
    }

    /// The line under the title: where it works, or what to do.
    func detail(now: Date = .now) -> String {
        switch state {
        case let .connectedHere(folder):
            return joined([String(localized: "Project \(folder)"), draftsText, lastCallText(now: now)])
        case let .connectedElsewhere(folder, owner):
            let place = owner.map { String(localized: "It works in \(folder), \($0)’s project.") } ?? String(localized: "It works in \(folder).")
            guard let appFolder else { return String(localized: "\(place) Choose \(appName)’s project folder so it reads the right code.") }
            if startsRuns {
                return String(localized: "\(place) Suggest Everything starts it in \(appFolder) for \(appName).")
            }
            return String(localized: "\(place) Open it in \(appFolder) to read \(appName)’s code.")
        case let .connectedUnsure(folder):
            guard let folder else { return String(localized: "Its folder is unknown. Choose \(appName)’s project folder.") }
            return String(localized: "It works in \(folder). If that’s \(appName)’s project, choose it as the app’s folder.")
        case let .refused(date, _):
            return String(localized: """
            Refused \(Self.ago(date, now: now)): its token is from an older pairing. Reconnect gives it a new one.
            """)
        case .readyToStart:
            let start = appFolder.map { String(localized: "Atlas starts it in \($0)") }
                ?? String(localized: "Atlas asks for \(appName)’s project folder the first time")
            return joined([start, draftsText])
        case .notConnected:
            let open = appFolder.map { String(localized: "Open it in \($0) to connect") }
                ?? String(localized: "Open it in \(appName)’s project folder to connect")
            return joined([open, lastCallText(now: now)])
        }
    }

    /// The card's buttons beside Suggest Everything… and Details.
    var actions: [Action] {
        switch state {
        case .refused: [.reconnect]
        case .connectedElsewhere, .connectedUnsure, .readyToStart: appFolder == nil ? [.chooseFolder] : []
        case .connectedHere, .notConnected: []
        }
    }

    var tone: Tone {
        switch state {
        case .connectedHere, .readyToStart: .good
        case .connectedElsewhere, .connectedUnsure, .notConnected: .attention
        case .refused: .problem
        }
    }

    /// Suggest Everything… can do something: a session is open, or Atlas
    /// starts Claude Code itself.
    var canSuggestEverything: Bool {
        switch state {
        case .connectedHere, .connectedElsewhere, .connectedUnsure, .readyToStart: true
        case .refused, .notConnected: startsRuns
        }
    }

    private var draftsText: String {
        editsDrafts ? String(localized: "suggests and edits drafts") : String(localized: "suggests only")
    }

    private func lastCallText(now: Date) -> String? {
        lastCall.map { String(localized: "last call \(Self.ago($0, now: now))") }
    }

    private func joined(_ parts: [String?]) -> String {
        parts.compactMap(\.self).joined(separator: " · ")
    }

    /// "a moment ago", "2 minutes ago".
    static func ago(_ date: Date, now: Date) -> String {
        guard now.timeIntervalSince(date) >= 60 else { return String(localized: "a moment ago") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

//
//  ConnectDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Welcome and Connect DEBUG scenes (`-AtlasDebugScene <id>`), as the
/// design's board 45 shows them:
///
/// - `welcome`: Welcome, the header moving; Get Started opens Connect.
/// - `welcome-still`: Welcome as Reduce Motion shows it.
/// - `welcome-short`: Welcome under 680 points high: no quiet line, the
///   points keep only their titles.
/// - `connect`: the empty form under the compact header; any well-formed
///   key connects, then the first sync runs and the library opens. Back
///   returns to Welcome.
/// - `connect-filled`: Issuer ID and the key filled in, Connect ready.
/// - `connect-key`: the same with a `.p8` already imported (a UI test can't
///   drive the file panel).
/// - `connect-hover`: a file hovering over the drop zone.
/// - `connect-hints`: malformed IDs and a file that isn't a key.
/// - `connect-how`: the empty form, and Show Me How's Help window open at
///   "Connect to App Store Connect" beside it.
/// - `connect-short`: the filled form in a window under 680 points high and
///   900 wide: only the steps and fields, no hints beside the names.
/// - `connect-checking`: the check never answers.
/// - `connect-401` (also `connect-rejected`), `connect-403`, `connect-offline`:
///   the check fails that way after Connect.
/// - `sync`: "Reading your apps…" halfway through; Cancel goes back to
///   Welcome.
/// - `sync-still`: the same as Reduce Motion shows it.
/// - `sync-done`: every app read, "Your 6 apps are ready" with Open Atlas.
/// - `addkey`: "Add Another Key…" over the library while Northpier Studio
///   is connected, the form filled in; Connect adds Fieldworks Studio.
/// - `addkey-403`: the same with a key whose role is too low: the error
///   sits under the fields and the key file is cleared.
/// - `addkey-check`: the same, Connect clicked: "Checking the new key…"
///   with Cancel, the check never answering.
/// - `addkey-done`: Fieldworks Studio added, Keep Northpier Studio or
///   Switch to Fieldworks Studio.
enum ConnectDebugScenes {
    static let ids = [
        "welcome", "welcome-still", "welcome-short",
        "connect", "connect-filled", "connect-key", "connect-hover", "connect-hints", "connect-how", "connect-short", "connect-checking",
        "connect-401", "connect-rejected", "connect-403", "connect-offline", "sync", "sync-still", "sync-done",
        "addkey", "addkey-403", "addkey-check", "addkey-done",
    ]

    /// The team every added key in a DEBUG scene belongs to.
    static let addedTeamName = "Fieldworks Studio"

    /// The key check every scene uses, in the main window and Settings.
    static func keyChecker(for id: String) -> any KeyChecker {
        switch id {
        case "connect-401", "connect-rejected": DebugKeyChecker(error: AppStoreConnectError.unauthorized)
        case "connect-403", "addkey-403": DebugKeyChecker(error: AppStoreConnectError.forbidden(detail: nil))
        case "connect-offline": DebugKeyChecker(error: URLError(.notConnectedToInternet))
        case "connect-checking", "addkey-check": DebugKeyChecker(delay: .seconds(3600))
        default: DebugKeyChecker()
        }
    }

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        if id.hasPrefix("sync") {
            return AnyView(SyncScene(isStill: id == "sync-still", isDone: id == "sync-done"))
        }
        if id.hasPrefix("addkey") {
            return AnyView(AddKeyDebugScene(id: id))
        }
        return AnyView(Scene(id: id))
    }

    /// One connect scene: the form in its state, and the library (after the
    /// first sync) once a key connects.
    private struct Scene: View {
        let id: String
        @State private var connection: Connection
        @State private var model: ConnectViewModel
        @Environment(\.openWindow) private var openWindow

        init(id: String) {
            self.id = id
            let connection = Connection()
            _connection = State(initialValue: connection)
            _model = State(initialValue: ConnectDebugScenes.model(for: id) { _, _ in connection.isConnected = true })
        }

        var body: some View {
            if connection.isConnected {
                DebugMainScene(isFirstSync: true)
            } else {
                content
                    .task {
                        if id == "connect-how" {
                            HelpNavigation.shared.open(ConnectBeforeYouStart.helpArticleID)
                            openWindow(id: HelpCommands.windowID)
                        }
                        if Self.connectsOnLaunch.contains(id) { await model.connect() }
                    }
            }
        }

        @ViewBuilder
        private var content: some View {
            // A file hovering is the form alone, as the old board drew it.
            if id == "connect-hover" {
                ConnectView(viewModel: model, showsDropHover: true)
                    .navigationTitle("Atlas")
            } else if Self.isShort(id) {
                flow
                    .frame(width: Self.shortSize.width, height: Self.shortSize.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                flow
            }
        }

        private var flow: some View {
            WelcomeFlowView(
                checker: ConnectDebugScenes.keyChecker(for: id),
                stage: id.hasPrefix("welcome") ? .welcome : .connect,
                viewModel: model,
                forcesStill: id == "welcome-still"
            ) { _, _ in connection.isConnected = true }
        }

        /// Under 680 points high and 900 wide (README-Welcome).
        static let shortSize = CGSize(width: 860, height: 620)

        static func isShort(_ id: String) -> Bool {
            id == "connect-short" || id == "welcome-short"
        }

        private static let connectsOnLaunch: Set = ["connect-checking", "connect-401", "connect-403", "connect-offline"]
    }

    /// "Reading your apps…" with three of the sample apps read; Cancel
    /// goes back to Welcome, as forgetting the only key does.
    private struct SyncScene: View {
        let isStill: Bool
        var isDone = false
        @State private var isCancelled = false
        @State private var isOpened = false

        var body: some View {
            if isCancelled {
                WelcomeFlowView(checker: DebugKeyChecker(), forcesStill: isStill) { _, _ in }
            } else if isOpened {
                DebugMainScene()
            } else {
                let read = isDone ? DebugFixtures.apps.count : 3
                FirstSyncView(
                    progress: FirstSyncProgress(
                        appCount: DebugFixtures.apps.count,
                        syncedCount: read,
                        teamName: DebugFixtures.northpier.name,
                        syncedNames: DebugFixtures.apps.prefix(read).map(\.name)
                    ),
                    forcesStill: isStill,
                    onCancel: { isCancelled = true },
                    onOpen: isDone ? { isOpened = true } : nil
                )
            }
        }
    }

    /// Whether a scene's key connected; a class, so the model's `onConnect`
    /// can flip it.
    @MainActor
    @Observable
    final class Connection {
        var isConnected = false
    }

    @MainActor
    private static func model(
        for id: String,
        onConnect: @escaping (AppStoreConnectCredentials, KeyAccessCheck) throws -> Void
    ) -> ConnectViewModel {
        let model = ConnectViewModel(checker: keyChecker(for: id), onConnect: onConnect)
        switch id {
        case "connect", "connect-how", "welcome", "welcome-still", "welcome-short":
            break
        case "connect-key":
            model.importKey(DebugFixtures.privateKey)
        case "connect-hover":
            model.issuerID = DebugFixtures.issuerID
            model.keyID = DebugFixtures.keyID
        case "connect-hints":
            model.issuerID = "69a6de7f-3c2e-47e3"
            model.keyID = "2X9R4H"
            model.leave(.issuerID)
            model.leave(.keyID)
            model.importKey(ImportedPrivateKey(fileName: "notes.txt", pem: "Remember to rotate the keys."))
        default:
            model.issuerID = DebugFixtures.issuerID
            model.importKey(DebugFixtures.privateKey)
        }
        return model
    }
}
#endif

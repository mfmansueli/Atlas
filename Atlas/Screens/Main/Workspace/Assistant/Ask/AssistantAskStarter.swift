//
//  AssistantAskStarter.swift
//  Atlas
//

import AppKit

/// Starts a request to Claude Code from somewhere with no asking button
/// of its own on screen: the Autopilot bar, or a section acting on one of
/// its actions. Like `ClaudeCodeAskButton`, it sends the request to the
/// bar (board 56, board 80) and starts Claude Code; without its helper it
/// copies the prompt to paste instead.
@MainActor
enum AssistantAskStarter {
    enum Outcome: Equatable {
        /// Sent to the toolbar; Claude Code is starting.
        case sent
        /// Atlas can't start Claude Code: the prompt is on the clipboard.
        case copied
        /// The app has a request running already.
        case busy
    }

    @discardableResult
    static func start(
        _ ask: WorkspaceAutopilotAsk, app: StoreApp, client: String, launcher: ClaudeCodeLauncher, askCenter: AssistantAskCenter,
        from anchor: AskAnchor? = nil, reduceMotion: Bool, copy: @MainActor (String) -> Void = copyToPasteboard
    ) -> Outcome {
        guard askCenter.ask(for: app.id) == nil else { return .busy }
        guard launcher.canStart else {
            copy(ask.prompt)
            return .copied
        }
        let request = AssistantAsk(appID: app.id, client: client, subject: ask.subject)
        let done = ask.done
        let sent = askCenter.send(request, from: anchor, reduceMotion: reduceMotion) { run in
            AssistantAskCenter.endingText(run, client: client, done: done)
        }
        guard sent else { return .busy }
        let prompt = ask.prompt
        let purpose = ask.purpose
        Task {
            if let runID = await launcher.start(purpose, appID: app.id, appName: app.name, prompt: prompt) {
                askCenter.attach(runID: runID, to: request.id)
            } else {
                // No folder chosen, so nothing was asked.
                askCenter.cancel(request.id)
            }
        }
        return .sent
    }

    /// The toast after `.copied`.
    static func copiedText(client: String) -> String {
        String(localized: "Copied. Paste it into \(client) in the app’s folder. Suggestions show here.")
    }

    static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

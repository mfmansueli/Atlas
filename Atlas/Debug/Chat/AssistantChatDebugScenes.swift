//
//  AssistantChatDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Board 69: the assistant chat in the window's corner, on Lumen Journal's
/// Pricing, with the pretend helper (`DebugUnixScriptRunner`) answering
/// every question after a few steps:
/// - `chat-ready`: closed, ready to ask; `chat-open`: open and empty.
/// - `chat-asking`, `chat-working`: a question being answered, open and
///   closed (the pretend run never ends).
/// - `chat-answer`, `chat-unseen`: an answer with a suggestion card, open,
///   and closed before it was seen.
/// - `chat-needs`, `chat-needs-open`: the assistant asks with
///   `ask_in_chat`; a quick reply is answered by the pretend helper.
/// - `chat-draft`: closed with a draft kept (Store Page).
/// - `chat-push`: closed while a push runs.
/// - `chat-error`, `chat-error-open`: Claude Code stopped.
/// - `chat-none`, `chat-none-open`: no helper, so no assistant to ask.
enum AssistantChatDebugScenes {
    static let ids = [
        "chat-ready", "chat-open", "chat-asking", "chat-working", "chat-answer", "chat-unseen", "chat-needs",
        "chat-needs-open", "chat-draft", "chat-push", "chat-error", "chat-error-open", "chat-none", "chat-none-open",
    ]

    static let appName = "Lumen Journal"
    static let question = "Which countries lose the most sales?"
    static let answer = "Brazil, India and Mexico. Most people there leave at the price screen, and lower annual prices win back the most."

    /// The pretend helper: what every chat run prints.
    static func script(for id: String) -> DebugUnixScriptRunner.Script {
        typealias Line = DebugUnixScriptRunner.Line
        typealias Stream = ClaudeCodeDebugStream
        let steps = [
            Line(delay: .milliseconds(300), text: Stream.started()),
            Line(delay: .milliseconds(400), text: Stream.atlas("get_analytics_funnel", id: "c1")),
            Line(delay: .milliseconds(400), text: Stream.atlas("get_prices", id: "c2")),
        ]
        if id == "chat-asking" || id == "chat-working" { return DebugUnixScriptRunner.Script(lines: steps, exitStatus: nil) }
        return DebugUnixScriptRunner.Script(lines: steps + [
            Line(delay: .milliseconds(400), text: Stream.said(answer)),
            Line(delay: .milliseconds(100), text: Stream.result(text: answer)),
        ])
    }

    /// The pretend helper for a scene: none for the ones without an assistant.
    static func runner(for id: String) -> DebugUnixScriptRunner {
        var runner = DebugUnixScriptRunner()
        runner.script = script(for: id)
        runner.helperExists = !id.hasPrefix("chat-none")
        return runner
    }

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        let section: AppWorkspaceSection = id == "chat-draft" ? .storePage : .subscriptionPricing
        let scene = DebugMainScene(section: section, autoPush: id == "chat-push")
        return AnyView(scene.modifier(Asks(id: id, section: section)))
    }

    /// Lumen Journal's chat in the scene's state, set as the scene appears.
    private struct Asks: ViewModifier {
        let id: String
        let section: AppWorkspaceSection
        @Environment(ClaudeCodeLauncher.self) private var launcher

        func body(content: Content) -> some View {
            content.task { await apply() }
        }

        private var context: AssistantChatContext {
            AssistantChatContext(appID: DebugFixtures.AppID.lumen, appName: AssistantChatDebugScenes.appName, section: section, version: "1.4")
        }

        private func apply() async {
            let center = AssistantChatCenter.shared
            let appID = DebugFixtures.AppID.lumen
            let opens = ["chat-open", "chat-asking", "chat-answer", "chat-needs-open", "chat-error-open", "chat-none-open"].contains(id)
            switch id {
            case "chat-asking", "chat-working":
                center.setOpen(opens)
                let launcher = launcher
                let context = context
                await center.send(AssistantChatDebugScenes.question, context: context) { prompt, session in
                    await launcher.start(.chat, appID: context.appID, appName: context.appName, prompt: prompt, resuming: session)
                }
            case "chat-answer", "chat-unseen":
                center.debugSet(chat(.answered(text: AssistantChatDebugScenes.answer, suggestions: suggestions), unseen: !opens), for: appID, isOpen: opens)
            case "chat-needs", "chat-needs-open":
                let question = AssistantChatQuestion(text: "Count every product, or only subscriptions?", choices: ["Only Subscriptions", "Every Product"])
                var waiting = chat(.needsYou(question), unseen: !opens)
                waiting.sessionID = ClaudeCodeDebugStream.sessionID
                center.debugSet(waiting, for: appID, isOpen: opens)
            case "chat-draft":
                var drafted = AssistantChat()
                drafted.draft = "Make the Japanese subtitle shorter"
                center.debugSet(drafted, for: appID, isOpen: false)
            case "chat-error", "chat-error-open":
                center.debugSet(chat(.failed(.claudeError("Overloaded")), unseen: !opens), for: appID, isOpen: opens)
            default:
                center.debugSet(AssistantChat(), for: appID, isOpen: opens)
            }
        }

        private var suggestions: AssistantChatSuggestions {
            AssistantChatSuggestions(
                targets: ["Lumen Plus Annual · Brazil", "Lumen Plus Annual · India", "Lumen Plus Annual · Mexico"], section: .subscriptionPricing
            )
        }

        private func chat(_ state: AssistantChatTurn.State, unseen: Bool) -> AssistantChat {
            var turn = AssistantChatTurn(id: UUID(), text: AssistantChatDebugScenes.question, askedAt: .now.addingTimeInterval(-40))
            turn.state = state
            turn.endedAt = .now.addingTimeInterval(-5)
            var chat = AssistantChat(turns: [turn])
            chat.isUnseen = unseen
            return chat
        }
    }
}
#endif

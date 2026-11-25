//
//  AutopilotBarDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Board 80: the Autopilot bar at the bottom of Lumen Journal's sections,
/// with the pretend helper (`DebugUnixScriptRunner`) answering every
/// question and request after a few steps:
/// - `bar-idle`: closed on Store Page, nothing happening.
/// - `bar-run`, `bar-open-run`: a request sent with one of the bar's
///   buttons (Write What's New), at its second step: “2 of 3” (the pretend
///   run never ends), closed and open.
/// - `bar-chat-run`: closed while a typed question is answered.
/// - `bar-needs`, `bar-open-needs`: the assistant asks with
///   `ask_in_chat`; its answers are buttons on the strip, purple.
/// - `bar-done`: closed, a request just finished: Done with Show.
/// - `bar-ready`: closed, an answer with a suggestion not seen yet (Pricing).
/// - `bar-err`: closed, Claude Code stopped: amber, Try Again.
/// - `bar-open`: open and empty: the section's actions and three questions.
/// - `bar-open-answer`: open on an answer with a suggestion card (Pricing).
/// - `bar-hist`: open with two requests under Earlier today.
/// - `bar-none`: open with no helper, so no assistant to ask: Connect….
/// - `bar-free`: closed on Free: the actions that do things carry PRO.
/// - `bar-width`: the closed field alone at the widths it meets, from the
///   default window to 860 × 560 with the sidebar: the buttons fold into
///   More one at a time.
/// - `bar-motion`: opens and closes by itself every `motionInterval`, to
///   watch it grow up and shrink back, with and without Reduce Motion.
enum AutopilotBarDebugScenes {
    static let ids = [
        "bar-idle", "bar-run", "bar-chat-run", "bar-needs", "bar-done", "bar-ready", "bar-err", "bar-open", "bar-open-run", "bar-open-needs",
        "bar-open-answer", "bar-hist", "bar-none", "bar-free", "bar-width", "bar-motion",
    ]

    static let appName = "Lumen Journal"
    /// How long `bar-motion` stays open, then closed.
    static let motionInterval: Duration = .seconds(2)
    static let question = "Which countries lose the most sales?"
    static let answer = "Brazil, India and Mexico. Most people there leave at the price screen, and lower annual prices win back the most."
    /// What `bar-run`'s request works on.
    static let subject = "Store Page · What’s New"

    /// The pretend helper: what every run prints.
    static func script(for id: String) -> DebugUnixScriptRunner.Script {
        typealias Line = DebugUnixScriptRunner.Line
        typealias Stream = ClaudeCodeDebugStream
        let steps = [
            Line(delay: .milliseconds(300), text: Stream.started()),
            Line(delay: .milliseconds(400), text: Stream.atlas("get_analytics_funnel", id: "c1")),
            Line(delay: .milliseconds(400), text: Stream.atlas("get_prices", id: "c2")),
        ]
        switch id {
        case "bar-run", "bar-open-run", "bar-chat-run":
            return DebugUnixScriptRunner.Script(lines: steps, exitStatus: nil)
        default:
            break
        }
        return DebugUnixScriptRunner.Script(lines: steps + [
            Line(delay: .milliseconds(400), text: Stream.said(answer)),
            Line(delay: .milliseconds(100), text: Stream.result(text: answer)),
        ])
    }

    /// The pretend helper for a scene: none for the one without an assistant.
    static func runner(for id: String) -> DebugUnixScriptRunner {
        var runner = DebugUnixScriptRunner()
        runner.script = script(for: id)
        runner.helperExists = id != "bar-none"
        return runner
    }

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        if id == "bar-width" { return AnyView(Widths()) }
        let section = section(for: id)
        let scene = DebugMainScene(section: section, isFree: id == "bar-free")
        return AnyView(scene.modifier(Apply(id: id, section: section)))
    }

    private static func section(for id: String) -> AppWorkspaceSection {
        ["bar-ready", "bar-open-answer", "bar-needs", "bar-open-needs", "bar-chat-run", "bar-err"].contains(id) ? .subscriptionPricing : .storePage
    }

    /// Lumen Journal's bar in the scene's state, set as the scene appears.
    private struct Apply: ViewModifier {
        let id: String
        let section: AppWorkspaceSection
        @Environment(ClaudeCodeLauncher.self) private var launcher

        func body(content: Content) -> some View {
            content.task { await apply() }
        }

        private var context: AssistantChatContext {
            AssistantChatContext(appID: DebugFixtures.AppID.lumen, appName: AutopilotBarDebugScenes.appName, section: section, version: "1.4")
        }

        private func apply() async {
            let center = AssistantChatCenter.shared
            let bar = AutopilotBarCenter.shared
            let appID = DebugFixtures.AppID.lumen
            let opens = id.hasPrefix("bar-open") || ["bar-hist", "bar-none"].contains(id)
            bar.debugSet(appID: appID)
            switch id {
            case "bar-run", "bar-open-run":
                center.debugSet(AssistantChat(), for: appID, isOpen: opens)
                await sendRequest()
            case "bar-chat-run":
                center.setOpen(false)
                let launcher = launcher
                await center.send(AutopilotBarDebugScenes.question, context: context) { prompt, session in
                    await launcher.start(.chat, appID: appID, appName: AutopilotBarDebugScenes.appName, prompt: prompt, resuming: session)
                }
            case "bar-needs", "bar-open-needs":
                let question = AssistantChatQuestion(text: "Count every product, or only subscriptions?", choices: ["Only Subscriptions", "Every Product"])
                var waiting = chat(.needsYou(question), unseen: !opens)
                waiting.sessionID = ClaudeCodeDebugStream.sessionID
                center.debugSet(waiting, for: appID, isOpen: opens)
            case "bar-done":
                center.debugSet(AssistantChat(), for: appID, isOpen: false)
                let done = finished("Suggest Texts · Store Page · German", result: "6 suggestions", ago: 5)
                bar.debugSet(appID: appID, done: done, finished: [done])
            case "bar-ready", "bar-open-answer":
                center.debugSet(chat(.answered(text: AutopilotBarDebugScenes.answer, suggestions: suggestions), unseen: !opens), for: appID, isOpen: opens)
            case "bar-err":
                center.debugSet(chat(.failed(.claudeError("Overloaded")), unseen: true), for: appID, isOpen: false)
            case "bar-hist":
                center.debugSet(chat(.answered(text: AutopilotBarDebugScenes.answer, suggestions: suggestions), unseen: false), for: appID, isOpen: true)
                bar.debugSet(appID: appID, finished: [
                    finished("Suggest Texts · Store Page · German", result: "6 suggestions", ago: 300),
                    finished("Translate · Store Page · Japanese", result: "9 suggestions", ago: 1800),
                ])
            case "bar-motion":
                center.debugSet(AssistantChat(), for: appID, isOpen: false)
                while !Task.isCancelled {
                    try? await Task.sleep(for: AutopilotBarDebugScenes.motionInterval)
                    if !Task.isCancelled { center.toggle() }
                }
            default:
                center.debugSet(AssistantChat(), for: appID, isOpen: opens)
            }
        }

        /// What a click on Write What's New sends, as the bar sends it.
        private func sendRequest() async {
            let appID = DebugFixtures.AppID.lumen
            let askCenter = AssistantAskCenter.shared
            let ask = AssistantAsk(appID: appID, client: MCPClientKind.claudeCode.title, subject: AutopilotBarDebugScenes.subject)
            AutopilotBarCenter.shared.send(AutopilotBarRequest(
                appID: appID, title: "What’s New", action: .writeWhatsNew, section: section, sentAt: .now
            ))
            guard askCenter.send(ask, from: nil, reduceMotion: true) else { return }
            if let runID = await launcher.start(.chat, appID: appID, appName: AutopilotBarDebugScenes.appName, prompt: "Write What's New") {
                askCenter.attach(runID: runID, to: ask.id)
            }
        }

        private func finished(_ what: String, result: String, ago seconds: TimeInterval) -> AutopilotBarFinished {
            AutopilotBarFinished(
                appID: DebugFixtures.AppID.lumen, what: what, result: result,
                text: "Its suggestions are marked in purple. Nothing is sent until you push.", section: .storePage,
                endedAt: .now.addingTimeInterval(-seconds)
            )
        }

        private var suggestions: AssistantChatSuggestions {
            AssistantChatSuggestions(
                targets: ["Lumen Plus Annual · Brazil", "Lumen Plus Annual · India", "Lumen Plus Annual · Mexico"], section: .subscriptionPricing
            )
        }

        private func chat(_ state: AssistantChatTurn.State, unseen: Bool) -> AssistantChat {
            var turn = AssistantChatTurn(id: UUID(), text: AutopilotBarDebugScenes.question, askedAt: .now.addingTimeInterval(-40))
            turn.state = state
            turn.endedAt = .now.addingTimeInterval(-5)
            var chat = AssistantChat(turns: [turn])
            chat.isUnseen = unseen
            return chat
        }
    }

    /// `bar-width`: the closed field at the widths it meets. The dock's
    /// bar at the default window (560), at 860 with the sidebar (the
    /// detail column's 604 less the sides and Review & Push), and narrower.
    private struct Widths: View {
        static let widths: [CGFloat] = [560, 420, 340, 260]

        private var actions: AutopilotBarActions {
            AutopilotBarActions(
                items: WorkspaceAutopilotAction.actions(for: .storePage).map {
                    WorkspaceAutopilotItem(action: $0, title: $0.title(version: "1.4", sourceLanguage: "English"))
                },
                everythingTitle: AutopilotBarActions.everythingTitle(section: .storePage, appName: AutopilotBarDebugScenes.appName)
            )
        }

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.large) {
                ForEach(Self.widths, id: \.self) { width in
                    VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                        Text(verbatim: "\(Int(width)) pt")
                            .atlasTextStyle(.subheadline)
                            .foregroundStyle(Palette.label2)
                        AutopilotBarSurface(isOpen: false, openHeight: Metrics.autopilotBarOpenHeight) {
                            AutopilotBarClosedField(
                                actions: actions, anchor: AskAnchor(), sectionTitle: AppWorkspaceSection.storePage.title, onOpen: {}, onAction: { _ in },
                                more: { room in
                                    ForEach(actions.more(fitting: room)) { item in Button(item.title) {} }
                                }
                            )
                        } open: {
                            EmptyView()
                        }
                        .frame(width: width)
                        .accessibilityIdentifier("barWidth.\(Int(width))")
                    }
                }
            }
            .padding(Spacing.xxLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.content)
        }
    }
}
#endif

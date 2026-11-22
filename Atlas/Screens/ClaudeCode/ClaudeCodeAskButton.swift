//
//  ClaudeCodeAskButton.swift
//  Atlas
//

import AppKit
import SwiftUI

/// "Ask Claude Code…" for one screen's job, e.g. In-App Texts' missing
/// texts or Pricing's subscriptions: starts Claude Code (once its helper is
/// saved) with `prompt`, or copies the prompt to paste. A started request
/// flies to the toolbar's Assistant button (board 56) and the app's asking
/// buttons say "Claude Code Is Working…" until the run ends, when the
/// window's toast says where the suggestions are. The popover is for the
/// prompt to paste; the proposals arrive in the screen and in Review & Push.
struct ClaudeCodeAskButton: View {
    let app: StoreApp
    /// Names the run, so the button finds its own.
    let purpose: ClaudeCodeRunPurpose
    let prompt: String
    /// The button's tooltip: "Ask Claude Code to …".
    let help: (_ client: String) -> String
    /// The popover's line while the run goes: "Claude Code reads … and proposes …".
    let explanation: (_ client: String) -> String
    /// `storePage.inAppTexts.ask`; the popover and prompt add `.popover` and `.prompt`.
    let identifier: String
    /// The button's title instead of "Ask Claude Code…", e.g. "Ask Claude
    /// Code to Draft One…".
    var title: ((_ client: String) -> String)?
    /// What the request is about, for the toolbar and the toast; nil is
    /// the purpose's.
    var subject: String?
    /// The toast's text when the run finished: where the suggestions are.
    var done: ((_ client: String) -> String)?

    @Environment(ClaudeCodeLauncher.self) private var launcher
    @Environment(MCPServerController.self) private var assistants
    @Environment(\.askCenterOverride) private var askCenterOverride
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var anchor = AskAnchor()
    @State private var isPresented = false
    @State private var askedAt: Date?
    @State private var copied = false

    private var client: String {
        assistants.sessions.first?.displayName ?? MCPClientKind.claudeCode.title
    }

    /// The run this button started, once it did.
    private var run: ClaudeCodeRun? {
        guard let askedAt else { return nil }
        return launcher.latestRun(appID: app.id, purpose: purpose, since: askedAt)
    }

    /// The app's request, from this button or another.
    private var appAsk: AssistantAsk? { askCenter.ask(for: app.id) }

    private var askCenter: AssistantAskCenter { askCenterOverride ?? .shared }

    var body: some View {
        Group {
            if let appAsk {
                // Can't be pressed, but says what's going on at full color.
                Button {} label: {
                    AskButtonLabel(title: appAsk.busyTitle)
                }
                .buttonStyle(AskBusyButtonStyle())
                .disabled(true)
            } else {
                Button(action: ask) {
                    AskButtonLabel(title: title?(client) ?? String(localized: "Ask \(client)…"))
                }
            }
        }
        .background(AskAnchorView(anchor: anchor))
        .help(Text(help(client)))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) { popover }
        // A run that failed says here how to get past it.
        .onChange(of: run?.failure != nil) {
            if run?.failure != nil { isPresented = true }
        }
        .accessibilityIdentifier(identifier)
    }

    /// Sends the request to the toolbar and starts Claude Code; without its
    /// helper, copies the prompt and shows it.
    private func ask() {
        if let run, run.isActive { return }
        askedAt = .now
        copied = false
        guard launcher.canStart else {
            copy()
            isPresented = true
            return
        }
        let client = client
        let ask = AssistantAsk(appID: app.id, client: client, subject: subject ?? purpose.askSubject)
        let finished = done?(client) ?? String(localized: "\(client) finished \(ask.subject). What it suggests is marked in purple.")
        let sent = askCenter.send(ask, from: anchor, reduceMotion: reduceMotion) { run in
            AssistantAskCenter.endingText(run, client: client, done: finished)
        }
        guard sent else { return }
        let prompt = prompt
        let purpose = purpose
        Task {
            if let runID = await launcher.start(purpose, appID: app.id, appName: app.name, prompt: prompt) {
                askCenter.attach(runID: runID, to: ask.id)
                return
            }
            // No folder chosen, so nothing was asked; or the helper went
            // away, so it's the paste after all.
            askCenter.cancel(ask.id)
            if !launcher.canStart {
                copy()
                isPresented = true
            }
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        copied = true
    }

    // MARK: - Popover

    private var popover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask \(client)")
                .font(.headline)
            if let run {
                Text(explanation(client))
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                ClaudeCodeRunStatusView(run: run, onShowOutput: {
                    isPresented = false
                    launcher.shownRunID = run.id
                }, onDismiss: { isPresented = false })
            } else if copied {
                Text("Atlas can’t start your assistant. Paste this into \(client); its proposals show up here and in Review & Push.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(prompt)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Spacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    .accessibilityIdentifier(identifier + ".prompt")
                HStack(spacing: Spacing.small) {
                    Text("Copied to the clipboard.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Copy Again", action: copy)
                        .controlSize(.small)
                }
                ClaudeCodeLaunchHint(client: client)
            } else {
                HStack(spacing: Spacing.small) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Starting \(client)…")
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                }
            }
        }
        .padding(Spacing.large)
        .frame(width: 420)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier + ".popover")
    }
}

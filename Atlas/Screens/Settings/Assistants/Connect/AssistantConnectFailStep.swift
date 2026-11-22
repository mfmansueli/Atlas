//
//  AssistantConnectFailStep.swift
//  Atlas
//

import AppKit
import SwiftUI

/// No answer (`set-wiz-fail`): what Atlas did and waited for, then the
/// usual reasons, each with the button that fixes it: Restart and Try
/// Again, Open the assistant (to sign in), Open Help.
struct AssistantConnectFailStep: View {
    let model: AssistantConnectModel
    let openHelp: () -> Void
    @Environment(AssistantConnector.self) private var connector

    /// Help's "Connect an AI assistant".
    static let helpArticle = "assistant"

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            AssistantConnectStepTitle(
                title: failure.title(for: model.assistant),
                detail: failure.detail(for: model.assistant, timeout: connector.answerTimeout)
            )
            VStack(spacing: 0) {
                reason(
                    title: firstReason.title,
                    detail: firstReason.detail,
                    button: String(localized: "Restart and Try Again"),
                    identifier: "restart",
                    action: model.retry
                )
                Divider()
                reason(
                    title: String(localized: "You haven’t signed in to \(name) yet"),
                    detail: model.assistant == .claudeCode
                        ? String(localized: "Open it once in Terminal, sign in, then try again.")
                        : String(localized: "Open it once, sign in, then try again."),
                    button: String(localized: "Open \(name)"),
                    identifier: "open",
                    action: openAssistant
                )
                Divider()
                reason(
                    title: String(localized: "Still nothing?"),
                    detail: String(localized: "Help has the steps to check, one by one."),
                    button: String(localized: "Open Help"),
                    identifier: "help",
                    action: openHelp
                )
            }
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.connect.reasons")
        }
    }

    private var name: String {
        model.assistant.title
    }

    private var failure: AssistantConnectFailure {
        model.failure ?? .noAnswer
    }

    /// Claude Code starts fresh each time, so "already open" means another
    /// thing for it.
    private var firstReason: (title: String, detail: String) {
        model.assistant == .claudeCode
            ? (
                String(localized: "Claude Code took too long to start"),
                String(localized: "The first start after an update can be slow. Atlas can start it again for you.")
            )
            : (
                String(localized: "\(name) was already open"),
                String(localized: "It only notices Atlas when it starts. Atlas can restart it for you.")
            )
    }

    private func reason(title: String, detail: String, button: String, identifier: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(button, action: action)
                .accessibilityIdentifier("settings.connect.reason.\(identifier)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }

    /// Claude Code opens in Terminal through its own link; the apps open
    /// themselves.
    private func openAssistant() {
        switch model.assistant {
        case .claudeCode:
            if !ClaudeCodeDeepLink.open(folder: model.folder ?? ProjectFolderPath.home, prompt: nil),
               let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
            {
                NSWorkspace.shared.openApplication(at: terminal, configuration: NSWorkspace.OpenConfiguration())
            }
        case .claudeForMac, .cursor:
            connector.apps.open(model.assistant)
        }
    }
}

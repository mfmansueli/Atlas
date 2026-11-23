//
//  AssistantConnectHelloStep.swift
//  Atlas
//

import SwiftUI

/// Step 3, "Say hello" (`set-wiz-hello`): Claude Code's own first message,
/// the dots while it writes (motion 7) and then its words arriving
/// (motion 3); below it, things to ask. Claude for Mac and Cursor can't be
/// asked by Atlas, so their bubble says what Atlas saw of them, and the
/// prompt to paste.
struct AssistantConnectHelloStep: View {
    let model: AssistantConnectModel
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            AssistantConnectStepTitle(title: title, detail: detail)
            message
            if model.assistant.answersAtlas == false { pastePrompt }
            thingsToAsk
        }
    }

    private var name: String {
        model.assistant.title
    }

    private var title: String {
        model.assistant.answersAtlas
            ? String(localized: "\(name) says hello")
            : String(localized: "\(name) is connected")
    }

    private var detail: String {
        model.assistant.answersAtlas
            ? String(localized: """
            \(name) wrote this message on your Mac and sent it to Atlas. The connection works.
            """)
            : String(localized: """
            This is what Atlas saw of \(name). Ask it below to say hello in its own words.
            """)
    }

    // MARK: - The message

    private var message: some View {
        HStack(alignment: .top, spacing: 10) {
            if model.hello?.isFromAssistant == false {
                Image(systemName: "globe")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                    .accessibilityHidden(true)
            } else {
                AssistantLogo(assistant: model.assistant, size: 26)
            }
            if let text = model.hello?.text {
                VStack(alignment: .leading, spacing: 7) {
                    Text(sender)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.label2)
                    ArrivingText(text)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("settings.connect.helloText")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.aiSurface, in: TypingIndicator.bubble)
                .overlay(TypingIndicator.bubble.strokeBorder(Palette.aiEdge, lineWidth: 1))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings.connect.hello")
            } else {
                TypingIndicator(label: String(localized: "\(name) is writing…"))
                Spacer(minLength: 0)
            }
        }
    }

    /// "Claude Code · just now", or "Atlas · just now" for what Atlas saw.
    private var sender: String {
        model.hello?.isFromAssistant == false
            ? String(localized: "Atlas · now")
            : String(localized: "\(name) · now")
    }

    private var pastePrompt: some View {
        HStack(spacing: Spacing.small) {
            Text(AssistantConnectPrompts.pastedHello(appName: model.appName))
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(copied ? String(localized: "Copied") : String(localized: "Copy")) {
                model.copyHelloPrompt()
                copied = true
            }
            .controlSize(.regular)
            .accessibilityIdentifier("settings.connect.copyHello")
        }
        .padding(Spacing.small)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }

    // MARK: - Next

    private var thingsToAsk: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("Things to ask \(name)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.label2)
            FlowLayout(spacing: Spacing.xSmall) {
                ForEach(AssistantConnectPrompts.thingsToAsk, id: \.self) { prompt in
                    Text(prompt)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Palette.fill1, in: Capsule())
                        .overlay(Capsule().strokeBorder(Palette.separator2, lineWidth: 0.5))
                }
            }
            Text("Or use Autopilot at the top of any section: it asks for you.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.connect.thingsToAsk")
    }
}

//
//  AssistantConnectProgressStep.swift
//  Atlas
//

import SwiftUI

/// Step 2, "Connect" (`set-wiz-busy`): Atlas adds itself, starts the
/// assistant and waits for its first message, each line checked off as it
/// passes. Claude Code without the helper stops at the first line with
/// Install Helper…, the one click the sandbox needs.
struct AssistantConnectProgressStep: View {
    let model: AssistantConnectModel
    @Environment(ClaudeCodeLauncher.self) private var launcher

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            AssistantConnectStepTitle(
                title: String(localized: "Connecting \(model.assistant.title)…"),
                detail: String(localized: "Atlas is doing the setup. There is nothing to type or copy; this takes a few seconds.")
            )
            VStack(alignment: .leading, spacing: 9) {
                ForEach(AssistantConnectModel.Progress.allCases, id: \.self) { line in
                    row(line)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Progress"))
            .accessibilityIdentifier("settings.connect.progress")
            if model.needsHelper { helper }
        }
    }

    private func row(_ line: AssistantConnectModel.Progress) -> some View {
        let state = ConnectStepMark.state(of: line.rawValue, current: model.progress.rawValue)
        return HStack(spacing: Spacing.small) {
            ConnectStepMark(number: line.rawValue, state: state, size: 16)
            Text(model.progressTitle(line))
                .font(.callout.weight(state == .now ? .medium : .regular))
                .foregroundStyle(state == .later ? Palette.label2 : Palette.label)
            if state == .now, !model.needsHelper {
                ProgressView()
                    .controlSize(.mini)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(state == .done ? "Done" : state == .now ? "Now" : ""))
        .accessibilityIdentifier("settings.connect.progress.\(line.rawValue)")
    }

    /// The helper isn't saved yet: one Save panel, then Connect goes on.
    private var helper: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.warningMark)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Atlas needs its helper to start Claude Code")
                    .font(.callout.weight(.semibold))
                Text("""
                The sandbox doesn’t let Atlas start programs itself. Install Helper… opens a Save panel in the right folder: just \
                click Save, and Connect goes on.
                """)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                if let error = launcher.installError {
                    InlineMessage.error(error)
                        .font(.subheadline)
                }
            }
            Spacer(minLength: Spacing.small)
            Button(launcher.helper.installTitle ?? String(localized: "Install Helper…")) {
                Task { await model.installHelper() }
            }
            .accessibilityIdentifier("settings.connect.installHelper")
        }
        .padding(Spacing.medium)
        .background(Palette.warningTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.connect.needsHelper")
    }
}

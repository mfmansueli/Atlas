//
//  AssistantSetupSnippetStep.swift
//  Atlas
//

import AppKit
import SwiftUI

/// Step 3, "Add to assistant": the command or configuration to copy, with
/// a token made for that client. For Claude Code it first asks how it
/// should reach Atlas: Atlas starts it (install the helper
/// once, then the project folder), or a command run in Terminal.
struct AssistantSetupSnippetStep: View {
    let viewModel: AssistantSetupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.offersLaunch {
                choice
            }
            if viewModel.launches, let launcher = viewModel.launcher {
                AssistantSetupLaunchStep(viewModel: viewModel, launcher: launcher)
            } else {
                snippet
            }
        }
    }

    private var choice: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("How should Claude Code reach Atlas?")
                .font(.body.weight(.semibold))
            AssistantSetupOptionRow(
                title: String(localized: "Atlas starts Claude Code"),
                detail: String(localized: """
                No Terminal, nothing to paste. Save a small helper once. Atlas then runs Claude Code in the project folder, \
                with a token per run, and shows what it does.
                """),
                badge: String(localized: "Recommended"),
                isSelected: viewModel.launches
            ) {
                viewModel.chooseLaunch(true)
            }
            .accessibilityIdentifier("assistantSetup.launch.start")
            AssistantSetupOptionRow(
                title: String(localized: "Run a command in Terminal"),
                detail: String(localized: "Add Atlas to Claude Code yourself, then paste each prompt into it."),
                isSelected: !viewModel.launches
            ) {
                viewModel.chooseLaunch(false)
            }
            .accessibilityIdentifier("assistantSetup.launch.terminal")
        }
    }

    private var snippet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.kind.setupIntro)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Text(viewModel.snippet ?? "")
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .accessibilityIdentifier("assistantSetup.snippet")
            HStack(spacing: Spacing.small) {
                Button {
                    if let snippet = viewModel.copySnippet() {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(snippet, forType: .string)
                    }
                } label: {
                    Label(viewModel.hasCopiedSnippet ? String(localized: "Copied") : viewModel.kind.copyTitle, systemImage: "doc.on.doc")
                }
                .accessibilityIdentifier("assistantSetup.copy")
                Text("Includes a new token for \(viewModel.kind.title) only.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            .controlSize(.regular)
            InlineMessage(text: viewModel.kind.setupNote, systemImage: "info.circle", tint: Palette.label2)
                .font(.subheadline)
        }
    }
}

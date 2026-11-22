//
//  AssistantConnectSheet.swift
//  Atlas
//

import SwiftUI

/// Connect's sheet (board 48, `set-wiz-*`): the assistant's tile and
/// "Connect Claude Code", the steps as pills, the step now, and its
/// buttons. Return is the primary button.
struct AssistantConnectSheet: View {
    let model: AssistantConnectModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, Spacing.medium)
            ScrollView {
                content
                    .padding(.horizontal, 22)
                    .padding(.top, Spacing.xxSmall)
                    .padding(.bottom, Spacing.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            Divider()
            footer
                .padding(.horizontal, 22)
                .padding(.vertical, Spacing.medium)
        }
        .frame(width: 600)
        .frame(minHeight: 420, idealHeight: 520)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.connect.sheet")
        .onDisappear { model.close() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AssistantLogo(assistant: model.assistant)
                Text("Connect \(model.assistant.title)")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Step \(model.stepIndex + 1) of \(model.stepTitles.count)")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("settings.connect.stepCount")
            }
            HStack(spacing: Spacing.xSmall) {
                ForEach(Array(model.stepTitles.enumerated()), id: \.offset) { index, title in
                    pill(index: index, title: title)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Steps"))
        }
    }

    private func pill(index: Int, title: String) -> some View {
        let state = ConnectStepMark.state(of: index, current: model.stepIndex)
        return HStack(spacing: 7) {
            ConnectStepMark(number: index + 1, state: state)
            Text(title)
                .font(.caption.weight(state == .now ? .semibold : .regular))
                .foregroundStyle(state == .later ? Palette.label2 : Palette.label)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, Spacing.xSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(state == .now ? Palette.accentTint : Palette.fill1, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(state == .done ? "Done" : state == .now ? "Now" : ""))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .folder: AssistantConnectFolderStep(model: model)
        case .connecting: AssistantConnectProgressStep(model: model)
        case .hello: AssistantConnectHelloStep(model: model)
        case .failed: AssistantConnectFailStep(model: model, openHelp: openHelp)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Spacing.small) {
            switch model.step {
            case .folder:
                cancel
                Spacer()
                Button("Connect Without a Project") { model.connect(withoutProject: true) }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("settings.connect.withoutProject")
                Button("Connect") { model.connect() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canConnect)
                    .accessibilityIdentifier("settings.connect.connect")
            case .connecting:
                Text("Keep this window open.")
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                Spacer()
            case .failed:
                cancel
                Spacer()
                Button("Try Again", action: model.retry)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("settings.connect.tryAgain")
            case .hello:
                Spacer()
                Button("Done", action: close)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("settings.connect.done")
                Button("Ask for a First Suggestion", action: askForSuggestion)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("settings.connect.firstSuggestion")
            }
        }
    }

    private var cancel: some View {
        Button("Cancel", action: close)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("settings.connect.cancel")
    }

    private func close() {
        model.close()
        dismiss()
    }

    private func askForSuggestion() {
        model.askForFirstSuggestion()
        close()
    }

    private func openHelp() {
        HelpNavigation.shared.open(AssistantConnectFailStep.helpArticle)
        openWindow(id: HelpCommands.windowID)
    }
}

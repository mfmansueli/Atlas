//
//  InfoPlistKeyCard.swift
//  Atlas
//

import AppKit
import SwiftUI

/// "Skip the question for every build": the export compliance key that
/// answers the question in the binary. Done when an assistant added it or
/// found it, when Atlas read it in the project, or (inferred) when the
/// newest uploads arrived already answered; else the key with Copy and Add
/// It to the Project, which asks Claude Code to add it once the answer is
/// settled.
struct InfoPlistKeyCard: View {
    @Bindable var viewModel: AppInformationViewModel
    var store = EncryptionKeyStore.shared
    var projects = EncryptionKeyProjectCenter.shared

    @Environment(ClaudeCodeLauncher.self) private var launcher
    @Environment(PushHistory.self) private var history: PushHistory?
    @State private var builds: [EncryptionKeyBuild] = []

    nonisolated static let snippet = EncryptionKeyAnswer.snippet(value: .no, code: nil)

    private var app: StoreApp { viewModel.app }

    private var isRunning: Bool {
        launcher.latestRun(appID: app.id, purpose: EncryptionKeyAskPrompt.purpose)?.isActive == true
    }

    var body: some View {
        let report = store.report(for: app.id)
        Card(padding: Spacing.medium + 2) {
            Text("Skip the question for every build")
                .font(.body.weight(.semibold))
            if let model = viewModel.encryptionKeyCard(
                report: report,
                project: projects.state(for: app.id),
                builds: builds,
                answeredInAtlas: EncryptionKeyDetection.answeredInAtlas(history?.records(for: app.id) ?? []),
                isRunning: isRunning
            ) {
                content(model)
            }
        }
        .task(id: launcher.projectFolderRevision) { await projects.refresh(app, launcher: launcher) }
        .task(id: app.id) { builds = await viewModel.services.recentBuilds(for: app) }
        .onChange(of: report?.date) {
            Task { await projects.refresh(app, launcher: launcher, force: true) }
        }
        .accessibilityIdentifier("appInformation.export.infoPlist")
    }

    @ViewBuilder
    private func content(_ model: EncryptionKeyCardModel) -> some View {
        if model.isDone, let headline = model.detection.headline {
            Label(headline, systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(Palette.ok)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("appInformation.export.key.status")
            if case let .reported(report) = model.detection {
                detailLine(report.byLine())
                    .accessibilityIdentifier("appInformation.export.key.by")
                if let notes = report.notes, !notes.isEmpty { detailLine(notes) }
            }
            if let detail = model.detection.detail {
                detailLine(detail)
                    .accessibilityIdentifier("appInformation.export.key.detail")
            }
        } else {
            Text("""
            Add this key to the app’s Info.plist, or the build setting to a target that generates its Info.plist, and \
            App Store Connect stops asking for every build you upload. It must say what the answers above say.
            """)
            .font(.callout)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
            if let conflict = model.conflictText {
                Label(conflict, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(Palette.warn)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("appInformation.export.key.conflict")
            }
            if let problem = model.problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(Palette.warn)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("appInformation.export.key.problem")
            }
            if let detail = model.detection.detail {
                detailLine(detail)
                    .accessibilityIdentifier("appInformation.export.key.detail")
            }
            snippetBox(model)
        }
        if model.isRunning {
            HStack(spacing: Spacing.small) {
                ProgressView()
                    .controlSize(.small)
                Text("Claude Code is working on the key in the project…")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("appInformation.export.key.running")
        }
        if model.showsButton {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                EncryptionKeyAskButton(app: app, answer: model.readiness.answer, title: model.buttonTitle)
                    .controlSize(.regular)
                if let reason = model.disabledReason {
                    Text(reason)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("appInformation.export.addKey.why")
                }
            }
        }
    }

    private func snippetBox(_ model: EncryptionKeyCardModel) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                // No custom accessibility label: on selectable text it sent
                // SwiftUI's accessibility into endless recursion (a crash).
                Text(model.snippet)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                Text(model.buildSetting)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Palette.label2)
                    .textSelection(.enabled)
            }
            Spacer(minLength: Spacing.medium)
            Button(String(localized: "Copy")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(model.snippet, forType: .string)
            }
            .controlSize(.regular)
            .accessibilityLabel(Text("Copy the Info.plist key"))
            .accessibilityIdentifier("appInformation.export.copyKey")
        }
        .padding(Spacing.small + 2)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
    }

    private func detailLine(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

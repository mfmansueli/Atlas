//
//  InAppEventDeepLinkCheckView.swift
//  Atlas
//

import SwiftUI

/// Under the deep link: whether the app opens it. What an assistant found
/// in the code ("Opens the event · checked by Claude Code in build 1.2.0
/// (21), tried in Simulator", "Doesn't open it yet"), else "Not checked"
/// with what Atlas read in the project folder (the link's scheme or domain
/// claimed or not), and the two asks: Check in the Code, Make It Work…. A
/// check made before the event's start or end moved says so: "Checked
/// before the dates changed".
struct InAppEventDeepLinkCheckView: View {
    @Bindable var viewModel: InAppEventsViewModel
    let event: InAppEvent

    @Environment(ClaudeCodeLauncher.self) private var launcher

    var body: some View {
        let report = viewModel.deepLinkReport(of: event)
        let claim = viewModel.linkClaim(of: event)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            if let report {
                Label(report.statusLine, systemImage: report.opens ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(report.opens ? Palette.ok : Palette.warn)
                    .accessibilityIdentifier("events.deepLink.status")
                if let stale = viewModel.deepLinkReportStaleText(of: event) {
                    Label(String(localized: "Checked before the dates changed: Check in the Code"), systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(Palette.warn)
                        .accessibilityIdentifier("events.deepLink.stale")
                    detailLine(stale)
                }
                if report.opens {
                    detailLine(String(localized: "Shows: \(report.shows)"))
                    if !report.beforeStart.isEmpty { detailLine(String(localized: "Before it starts: \(report.beforeStart)")) }
                    if report.needsPremium { detailLine(String(localized: "Needs Premium to open.")) }
                }
                ForEach(report.problems, id: \.self) { problem in
                    Label(problem, systemImage: "minus")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
            } else {
                Label(String(localized: "Not checked"), systemImage: "questionmark.circle")
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("events.deepLink.status")
            }
            if report == nil || claim.blocksSubmit, let message = claim.message(appName: viewModel.app.name) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(claim.blocksSubmit ? Palette.warn : Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("events.deepLink.claim")
                if let detail = claim.detail {
                    detailLine(detail)
                }
            }
            HStack(spacing: Spacing.small) {
                if claim.needsFolder {
                    Button("Choose the Project Folder…") { chooseFolder() }
                        .accessibilityIdentifier("events.deepLink.chooseFolder")
                }
                if event.state.isEditable {
                    InAppEventDeepLinkAskButton(
                        app: viewModel.app, event: event, deepLink: viewModel.deepLink(of: event), kind: .check,
                        identifier: "events.deepLink.check"
                    )
                    if report?.opens != true || claim.blocksSubmit {
                        InAppEventDeepLinkAskButton(
                            app: viewModel.app, event: event, deepLink: viewModel.deepLink(of: event), kind: .makeItWork,
                            identifier: "events.deepLink.makeItWork"
                        )
                    }
                }
            }
            .controlSize(.regular)
        }
        .font(.subheadline)
        .task(id: launcher.projectFolderRevision) { await viewModel.linkClaims.refresh(viewModel.app, launcher: launcher) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.deepLink.check.area")
    }

    private func detailLine(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func chooseFolder() {
        guard launcher.chooseProjectFolder(for: viewModel.app.id, appName: viewModel.app.name) != nil else { return }
        Task { await viewModel.linkClaims.refresh(viewModel.app, launcher: launcher, force: true) }
    }
}

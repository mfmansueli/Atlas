//
//  SubmitEventRow.swift
//  Atlas
//

import SwiftUI

/// One In-App Event in the Submit sheet: its tick, and under it, when
/// ticked, what App Store Connect still needs (with Fix…, which opens the
/// event's page, on its dates when one has passed), warnings about App
/// Review's time, the deep link check's warnings (with Use Build 21 when
/// the build chosen is older than the one checked) and a calm note when
/// nobody checked the link, with Check in the Code.
struct SubmitEventRow: View {
    @Bindable var viewModel: ReleaseViewModel
    let event: InAppEvent
    /// Fix…: the event's page, the sheet closed, on the first thing still
    /// needed.
    let onFix: (InAppEventReviewNeed?) -> Void

    @Environment(ClaudeCodeLauncher.self) private var launcher

    private var isTicked: Bool { viewModel.options.eventIDs.contains(event.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Toggle(isOn: Binding { isTicked } set: { viewModel.setEvent(event.id, goesWithVersion: $0) }) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("In-App Event “\(ReleaseViewModel.displayName(of: event))”")
                        .font(.callout)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.checkbox)
            .accessibilityIdentifier("submit.event.\(event.id)")
            if isTicked {
                checks(viewModel.preflight(of: event))
                    .padding(.leading, 20)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("submit.event.\(event.id).row")
    }

    /// "Major Update · Nov 24 – Dec 8 · 12 languages".
    private var detail: String {
        [event.badge?.title, event.datesText, ReviewText.languages(event.localizations.count)].compactMap(\.self).joined(separator: " · ")
    }

    private func checks(_ preflight: EventSubmitPreflight) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            if preflight.blocks {
                ForEach(preflight.missing) { item in
                    Label(item.text, systemImage: "xmark.circle.fill")
                        .foregroundStyle(Palette.warn)
                        .accessibilityIdentifier("submit.event.\(event.id).missing.\(item.id)")
                }
                HStack(spacing: Spacing.small) {
                    Button("Fix…") { onFix(preflight.missing.first?.need) }
                        .accessibilityIdentifier("submit.event.\(event.id).fix")
                    if preflight.offersFix { askButton(.makeItWork) }
                }
            }
            ForEach(preflight.reviewTime) { warning in
                Label(warning.text, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Palette.warn)
                    .accessibilityIdentifier("submit.event.\(event.id).reviewTime.\(warning.id)")
            }
            ForEach(preflight.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Palette.warn)
                    .accessibilityIdentifier("submit.event.\(event.id).warning")
            }
            if let build = preflight.newerBuild {
                Button("Use Build \(build.number)") { viewModel.useBuild(build) }
                    .accessibilityIdentifier("submit.event.\(event.id).useBuild")
            }
            if let note = preflight.note {
                Text(note)
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("submit.event.\(event.id).note")
            }
            if !preflight.blocks, preflight.offersCheck || preflight.offersFix {
                HStack(spacing: Spacing.small) {
                    if preflight.offersCheck { askButton(.check) }
                    if preflight.offersFix { askButton(.makeItWork) }
                    if case .noFolder = viewModel.eventLinkClaim(of: event) {
                        Button("Choose the Project Folder…") { chooseFolder() }
                            .accessibilityIdentifier("submit.event.\(event.id).chooseFolder")
                    }
                }
            }
        }
        .font(.subheadline)
        .controlSize(.regular)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func askButton(_ kind: InAppEventDeepLinkAskPrompt.Kind) -> some View {
        InAppEventDeepLinkAskButton(
            app: viewModel.app, event: event, deepLink: viewModel.eventDeepLink(of: event), kind: kind,
            identifier: "submit.event.\(event.id).\(kind == .check ? "check" : "makeItWork")"
        )
    }

    private func chooseFolder() {
        guard launcher.chooseProjectFolder(for: viewModel.app.id, appName: viewModel.app.name) != nil else { return }
        Task { await viewModel.linkClaims.refresh(viewModel.app, launcher: launcher, force: true) }
    }
}

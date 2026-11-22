//
//  SubmitForReviewSheet.swift
//  Atlas
//

import SwiftUI

/// Submit for Review: the build, What's New in every language, what goes
/// with the submission, the encryption question and what happens after
/// approval. Submit stays disabled until everything is there, and the
/// footer says exactly what's missing.
struct SubmitForReviewSheet: View {
    @Bindable var viewModel: ReleaseViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(ClaudeCodeLauncher.self) private var launcher

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            HStack(alignment: .top, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.large) {
                        buildSection
                        whatsNewSection
                    }
                    .padding(Spacing.xLarge)
                }
                .frame(maxWidth: .infinity)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.large) {
                        // Read again every minute: an event's date that
                        // passes while the sheet is open blocks it.
                        TimelineView(.everyMinute) { _ in goesWithSection }
                        encryptionSection
                        releaseSection
                    }
                    .padding(Spacing.xLarge)
                }
                .frame(width: 380)
            }
            Divider()
            TimelineView(.everyMinute) { _ in footer }
        }
        .frame(width: 840, height: 540)
        .disabled(viewModel.isSubmitting)
        .task { await keepBuildsFresh() }
        .task {
            // A deep link or art added on the event's page since shows here.
            await viewModel.refreshEvents()
            await viewModel.linkClaims.refresh(viewModel.app, launcher: launcher)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("submit.sheet")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(viewModel.submitTitle)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("submit.title")
            if !viewModel.submitSubtitle.isEmpty {
                Text(viewModel.submitSubtitle)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.large)
        .padding(.bottom, Spacing.medium)
    }

    // MARK: - Build

    private var buildSection: some View {
        SubmitSection(title: String(localized: "Build")) {
            if viewModel.isRefreshingBuilds {
                HStack(spacing: Spacing.xSmall) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking for new builds…")
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("submit.checkingBuilds")
            } else {
                Button("Check Again", systemImage: "arrow.clockwise") {
                    Task { await viewModel.refreshStatus() }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Look for builds uploaded since this opened")
                .accessibilityIdentifier("submit.checkBuilds")
            }
        } content: {
            let builds = viewModel.status?.builds ?? []
            if builds.isEmpty {
                Text("No build of \(viewModel.versionString) yet. Upload one from Xcode; it shows here once Apple has processed it.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
            ForEach(builds) { build in
                RadioRow(
                    title: build.detail, isSelected: viewModel.options.buildID == build.id, isDisabled: !build.isSelectable,
                    action: { select(build) },
                    leading: {
                        Text(build.title(version: viewModel.versionString))
                            .font(.callout.weight(.semibold).monospacedDigit())
                            .frame(width: 84, alignment: .leading)
                    }
                )
                .accessibilityIdentifier("submit.build.\(build.number)")
            }
            Text("Atlas checks every minute while this is open. A new upload shows a few minutes after Xcode finishes it.")
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Reads the builds when the sheet opens and every minute while it's
    /// open: Apple lists an upload a few minutes after Xcode sends it.
    private func keepBuildsFresh() async {
        await viewModel.refreshStatus()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            await viewModel.refreshStatus()
        }
    }

    /// Another build may carry another encryption answer.
    private func select(_ build: ReleaseBuild) {
        viewModel.options.buildID = build.id
        if let known = viewModel.knownEncryption { viewModel.options.encryption = known }
    }

    // MARK: - What's New

    private var whatsNewSection: some View {
        SubmitSection(title: viewModel.whatsNewTitle) {
            Text("Edited in Store Page")
                .font(.caption)
                .foregroundStyle(Palette.label2)
        } content: {
            let rows = viewModel.whatsNewRows
            if rows.isEmpty {
                Text("A first version has no What’s New.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    Divider()
                    SubmitWhatsNewRow(row: row) { suggestion in
                        Task { await viewModel.accept(suggestion) }
                    } onWrite: {
                        dismiss()
                        navigator.open(.storePage, intent: .showLanguage(row.locale.code))
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("submit.whatsNew")
    }

    // MARK: - Goes with this submission

    private var goesWithSection: some View {
        SubmitSection(title: String(localized: "Goes with this submission")) {
            if viewModel.pendingCount > 0 {
                Toggle(isOn: $viewModel.options.pushesChanges) {
                    caption(
                        viewModel.pendingCount == 1
                            ? String(localized: "Push 1 change with this submission")
                            : String(localized: "Push \(viewModel.pendingCount) changes with this submission"),
                        String(localized: "They wait in Review & Push. App Review sees them with \(viewModel.versionString).")
                    )
                }
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("submit.pushChanges")
            }
            ForEach(viewModel.offeredEvents) { event in
                SubmitEventRow(viewModel: viewModel, event: event) { need in
                    dismiss()
                    if let field = need?.dateField {
                        navigator.open(.inAppEvents, intent: .showInAppEventDates(eventID: event.id, field: field))
                    } else {
                        navigator.open(.inAppEvents, intent: .showInAppEvents(eventID: event.id))
                    }
                }
            }
            HStack(alignment: .top, spacing: Spacing.small) {
                StatusMark(isOK: viewModel.status?.isReviewInformationComplete ?? true, size: 18)
                caption(
                    String(localized: "Screenshots, age rating, App Review information"),
                    viewModel.status?.isReviewInformationComplete == false
                        ? String(localized: "App Review needs a contact, and the demo account when sign-in is required")
                        : String(localized: "As they are in App Store Connect")
                )
                Button("Open") {
                    dismiss()
                    navigator.open(.appInformation, intent: .openAppInformationPage(.appReview))
                }
                .buttonStyle(.link)
                .controlSize(.small)
                .accessibilityIdentifier("submit.openReviewInformation")
            }
        }
    }

    private func caption(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.callout)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Palette.label2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Encryption

    private var encryptionSection: some View {
        SubmitSection(title: String(localized: "Does \(viewModel.versionString) use encryption?")) {
            if viewModel.needsEncryptionAnswer {
                Pill(text: String(localized: "Needs an answer"), style: .warning)
                    .fixedSize()
                    .accessibilityIdentifier("submit.encryption.needed")
            }
        } content: {
            ForEach(EncryptionAnswer.allCases) { answer in
                RadioRow(title: answer.title, detail: answer.detail, isSelected: viewModel.options.encryption == answer) {
                    viewModel.options.encryption = answer
                }
                .accessibilityIdentifier("submit.encryption.\(answer.rawValue)")
            }
            Text("Saved to App Information → Export Compliance, so the next version asks only if something changed.")
                .font(.caption)
                .foregroundStyle(Palette.label2)
        }
    }

    // MARK: - After approval

    private var releaseSection: some View {
        SubmitSection(title: String(localized: "When App Review approves it")) {
            ForEach(ReleaseTiming.Kind.allCases) { kind in
                RadioRow(title: kind.title, detail: detail(kind), isSelected: viewModel.options.timing == kind) {
                    viewModel.options.timing = kind
                }
                .accessibilityIdentifier("submit.timing.\(kind.rawValue)")
            }
            if viewModel.options.timing == .scheduled {
                DatePicker("Not before", selection: $viewModel.options.releaseDate, in: viewModel.now()..., displayedComponents: [.date, .hourAndMinute])
                    .font(.callout)
                    .padding(.leading, 34)
                    .accessibilityIdentifier("submit.releaseDate")
            }
            Toggle(isOn: $viewModel.options.isPhased) {
                caption(String(localized: "Phased release"), viewModel.phasedDetail)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityIdentifier("submit.phased")
            HStack(alignment: .top, spacing: Spacing.small) {
                caption(
                    String(localized: "Reset the rating summary"),
                    String(localized: "Apple’s API can’t turn it on. To start \(viewModel.versionString) with a fresh rating, set it in App Store Connect before you submit.")
                )
                ExternalLinkButton(title: String(localized: "Open"), url: viewModel.appStoreConnectURL, isLink: true)
            }
        }
    }

    private func detail(_ kind: ReleaseTiming.Kind) -> String? {
        switch kind {
        case .afterApproval: nil
        case .manual: String(localized: "Atlas tells you when it’s approved.")
        case .scheduled: String(localized: "Apple releases it at the time you pick, or once it’s approved if that’s later.")
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            if let error = viewModel.submitError {
                InlineMessage.error(error)
                    .font(.callout)
                    .accessibilityIdentifier("submit.error")
            }
            HStack(spacing: Spacing.small) {
                if viewModel.isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(viewModel.footerText)
                    .font(.callout)
                    .foregroundStyle(viewModel.blockers.isEmpty ? Palette.label2 : Palette.warning)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("submit.footer")
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("submit.cancel")
                Button(viewModel.submitButtonTitle) {
                    Task {
                        if await viewModel.submit() { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canSubmit)
                .accessibilityIdentifier("submit.submit")
            }
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.vertical, Spacing.medium)
    }
}

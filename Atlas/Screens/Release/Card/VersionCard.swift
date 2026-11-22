//
//  VersionCard.swift
//  Atlas
//

import SwiftUI

/// The Overview's version card. Before submitting it lists what goes to
/// App Review and what's missing, with Submit for Review…; after, it
/// follows the version (Submitted → Waiting for Review → In Review →
/// Approved → On the App Store) and offers what can be done in that state.
struct VersionCard: View {
    @Bindable var viewModel: ReleaseViewModel
    let onSubmit: () -> Void
    let onOpenEvent: (InAppEvent.ID) -> Void
    let onOpenReviewInformation: () -> Void
    let onSeeReviews: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        Card {
            header
            if let error = viewModel.actionError ?? viewModel.errorMessage {
                InlineMessage.error(error)
                    .font(.callout)
                    .accessibilityIdentifier("overview.version.error")
            }
            switch viewModel.phase {
            case nil:
                EmptyView()
            case .prepare:
                prepare
            default:
                tracking
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview.version")
        .confirmationDialog(
            viewModel.confirming?.confirmation(version: viewModel.versionString) ?? "",
            isPresented: Binding { viewModel.confirming != nil } set: { if !$0 { viewModel.confirming = nil } },
            titleVisibility: .visible,
            presenting: viewModel.confirming
        ) { action in
            Button(action.confirmTitle(version: viewModel.versionString)) {
                Task { await viewModel.perform(action) }
            }
            .accessibilityIdentifier("overview.version.confirm")
            Button("Not Now", role: .cancel) {}
        } message: { action in
            Text(action.consequence(version: viewModel.versionString))
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Palette.sectionRelease, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.cardTitle)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("overview.version.title")
                Text(viewModel.cardSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let phase = viewModel.phase {
                Pill(text: phase.pillTitle, style: viewModel.pillStyle)
                    .fixedSize()
                    .accessibilityIdentifier("overview.version.pill")
            }
        }
    }

    // MARK: - Before submitting

    private var prepare: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            AdaptiveGridLayout(minimumWidth: 230, spacing: Spacing.medium) {
                ForEach(viewModel.checks) { check in
                    VersionCheckRow(check: check) { act(on: check) }
                }
            }
            HStack(spacing: Spacing.small) {
                Text("TestFlight and builds stay in Xcode and App Store Connect.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Submit for Review…", action: onSubmit)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("overview.version.submit")
            }
        }
    }

    private func act(on check: ReleaseCheck) {
        switch check.kind {
        case .whatsNew: onSubmit()
        case .event: check.eventID.map(onOpenEvent)
        case .reviewInformation: onOpenReviewInformation()
        case .build, .changes: break
        }
    }

    // MARK: - After submitting

    private var tracking: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            VersionTimeline(steps: viewModel.steps)
            if case let .phased(day, isPaused) = viewModel.phase {
                PhasedReleaseBar(day: day, isPaused: isPaused)
            }
            if viewModel.phase == .rejected {
                rejection
            }
            HStack(spacing: Spacing.small) {
                buttons
                if viewModel.busyAction != nil {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .buttonBorderShape(.capsule)
            .disabled(viewModel.busyAction != nil)
        }
    }

    /// Apple's message isn't something the API key can read.
    private var rejection: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("From App Review")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.label2)
            Text("""
            App Review wrote what it needs in App Store Connect. Read it there and reply there; the fix itself, such as the demo \
            account, can be made here.
            """)
            .font(.callout)
            .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.dangerTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("overview.version.rejection")
    }

    @ViewBuilder
    private var buttons: some View {
        let version = viewModel.versionString
        switch viewModel.phase {
        case .waitingForReview:
            Button("Cancel Submission") { viewModel.request(.cancelSubmission) }
                .disabled(viewModel.status?.submission?.canCancel != true)
                .accessibilityIdentifier("overview.version.cancel")
        case .pendingDeveloperRelease:
            Button("Release \(version) Now") { viewModel.request(.releaseNow) }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("overview.version.release")
        case .phased:
            Button(viewModel.pauseTitle) { viewModel.request(viewModel.pauseAction) }
                .accessibilityIdentifier("overview.version.pause")
            Button("Release to Everyone Now") { viewModel.request(.releaseToEveryone) }
                .accessibilityIdentifier("overview.version.releaseAll")
        case .rejected:
            Button("Read It in App Store Connect") { openURL(viewModel.appStoreConnectURL) }
                .accessibilityIdentifier("overview.version.readMessage")
            Button("Edit App Review Information", action: onOpenReviewInformation)
                .accessibilityIdentifier("overview.version.editReview")
            Button("Submit Again") {
                if viewModel.resubmitsDirectly {
                    viewModel.request(.submitAgain)
                } else {
                    onSubmit()
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("overview.version.resubmit")
        case .live:
            Button("See Reviews of \(version)", action: onSeeReviews)
                .accessibilityIdentifier("overview.version.reviews")
        case nil, .prepare, .inReview, .pendingAppleRelease:
            EmptyView()
        }
    }
}

//
//  VersionCard.swift
//  Atlas
//

import SwiftUI

/// The Overview's version card. Before submitting it lists what goes to
/// App Review and what's missing, with Submit for Review…; after, it
/// follows the version (Submitted → Waiting for Review → In Review →
/// Approved → On the App Store) and offers what can be done in that state.
/// While it follows the version, a notice about it (the crash banner) sits
/// under the steps.
struct VersionCard<Notice: View>: View {
    @Bindable var viewModel: ReleaseViewModel
    let onSubmit: () -> Void
    let onOpenEvent: (InAppEvent.ID) -> Void
    let onOpenReviewInformation: () -> Void
    let onSeeReviews: () -> Void
    /// Under the steps once submitted: Overview's crash banner.
    @ViewBuilder var notice: () -> Notice

    @Environment(\.openURL) private var openURL

    var body: some View {
        Card {
            header
            if let error = viewModel.actionError ?? viewModel.errorMessage {
                InlineMessage.error(error)
                    .font(.callout)
                    .accessibilityIdentifier("overview.version.error")
            }
            // An assistant's proposal over MCP, waiting for the person.
            if let proposal = viewModel.waitingProposal {
                ReleaseProposalBanner(viewModel: viewModel, proposal: proposal, onSubmit: onSubmit)
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
            // Neutral, like the prototype's: section colours are for the
            // sidebar's tiles (README — Design system §1).
            Image(systemName: "paperplane.fill")
                .font(.callout.weight(.medium))
                .foregroundStyle(Palette.raised)
                .frame(width: 26, height: 26)
                .background(Palette.label, in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.cardTitle)
                    .font(.body.weight(.semibold))
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

    /// Only what's missing, each with what fixes it; then one line for
    /// everything that's ready, beside Submit for Review… (README —
    /// redesign, November 22: "Overview is three lists").
    private var prepare: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.checks.filter { !$0.isOK }) { check in
                Divider()
                VersionCheckRow(check: check) { act(on: check) }
                    .padding(.vertical, Spacing.medium)
            }
            Divider()
            HStack(spacing: Spacing.medium) {
                StatusMark(isOK: true)
                Text(readyLine)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("overview.version.ready")
                Button("Submit for Review…", action: onSubmit)
                    .primaryButton()
                    .fixedSize()
                    .accessibilityIdentifier("overview.version.submit")
            }
            .padding(.top, Spacing.medium)
        }
    }

    /// "Ready: Build 1.4 (212) · Store Page, Screenshots and Pricing are
    /// pushed · In-App Event “Mood Calendar”".
    private var readyLine: String {
        let ready = viewModel.checks.filter(\.isOK).map(\.title)
        guard !ready.isEmpty else { return String(localized: "TestFlight and builds stay in Xcode and App Store Connect.") }
        return String(localized: "Ready: \(ready.joined(separator: " · "))")
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
            notice()
            if viewModel.phase == .rejected {
                rejection
            }
            HStack(spacing: Spacing.small) {
                Spacer(minLength: 0)
                if viewModel.busyAction != nil {
                    ProgressView()
                        .controlSize(.small)
                }
                buttons
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
            Read and reply to App Review in App Store Connect. Make the fix, such as the demo account, here.
            """)
            .font(.callout)
            .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, 10)
        .background(Palette.errTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
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

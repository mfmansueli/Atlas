//
//  GuidedChecksCard.swift
//  Atlas
//

import SwiftUI

/// Review & push's Checks, beside the part shown: what passed (✓), what
/// to look at (!), and a shortened caption to confirm with Looks Good or
/// change with Edit…; then Approve, and Edit Captions… for the
/// screenshots. What the design source can still change is asked beside
/// the part itself.
struct GuidedChecksCard: View {
    @Bindable var studio: ScreenshotStudioModel
    let run: AutopilotRun
    let part: GuidedReviewPart

    var body: some View {
        let checks = studio.guidedChecks(for: part)
        let isApproved = studio.isApproved(part)
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Checks").font(.callout.weight(.semibold))
            ForEach(checks) { check in
                row(check)
            }
            Divider().padding(.vertical, Spacing.xxSmall)
            Group {
                if isApproved {
                    Button {
                        studio.toggleApproval(part)
                    } label: {
                        Label("Approved", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .help(Text("Takes the approval back"))
                } else {
                    Button {
                        studio.toggleApproval(part)
                    } label: {
                        Text(part.approveTitle(plan: run.plan)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .buttonBorderShape(.capsule)
            .disabled(!studio.canApprove(part))
            .accessibilityAddTraits(isApproved ? .isSelected : [])
            .accessibilityIdentifier("autopilot.guided.review.approve")
            approveNote
            if part == .screenshots {
                Button("Edit Captions…") { studio.editGuidedCaptions() }
                    .buttonStyle(.link)
                    .frame(maxWidth: .infinity)
                    .help(Text("Opens every language’s captions"))
                    .accessibilityIdentifier("autopilot.guided.review.editCaptions")
            }
        }
        .font(.callout)
        .frame(width: 300, alignment: .leading)
        .modifier(GuidedSelectableCard())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("autopilot.guided.review.checks")
    }

    /// Why Approve is off and until when, while the header loop is made
    /// again.
    @ViewBuilder
    private var approveNote: some View {
        if part == .screenshots, !studio.guidedCaptionProposals.isEmpty {
            Text("Decide on the suggestion above first: it changes these screenshots.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("autopilot.guided.review.approveNote")
        } else if !studio.canApprove(part), let progress = AutopilotLoopProgress.make(run, now: .now) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text((AutopilotLoopProgress.make(run, now: context.date) ?? progress).approveNote)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
            .accessibilityIdentifier("autopilot.guided.review.approveNote")
        }
    }

    private func row(_ check: GuidedCheck) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                Image(systemName: mark(check.state))
                    .foregroundStyle(color(check.state))
                    .frame(width: Metrics.symbolColumn)
                    .accessibilityHidden(true)
                Text(check.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if check.state == .attention, !check.details.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    ForEach(check.details, id: \.self) { line in
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, Metrics.symbolColumn + Spacing.xSmall)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("autopilot.guided.review.check.\(check.id).details")
            }
            if let proposalID = check.proposalID {
                HStack(spacing: Spacing.xSmall) {
                    Button("Accept") { Task { await studio.acceptGuidedProposal(proposalID) } }
                        .rowActionButton()
                        .accessibilityIdentifier("autopilot.guided.review.check.\(check.id).accept")
                    Button("Reject") { Task { await studio.rejectGuidedProposal(proposalID) } }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("autopilot.guided.review.check.\(check.id).reject")
                }
                .controlSize(.regular)
                .buttonBorderShape(.capsule)
                .padding(.leading, Metrics.symbolColumn + Spacing.xSmall)
            }
            if check.state == .toConfirm {
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    ForEach(check.changes, id: \.self) { change in
                        Text(change)
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: Spacing.xSmall) {
                        Button("Looks Good") { studio.confirmShortenings(check) }
                            .accessibilityIdentifier("autopilot.guided.review.check.\(check.id).confirm")
                        Button("Edit…") { studio.editGuidedCaptions() }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("autopilot.guided.review.check.\(check.id).edit")
                    }
                    .controlSize(.regular)
                    .buttonBorderShape(.capsule)
                }
                .padding(.leading, Metrics.symbolColumn + Spacing.xSmall)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(label(check.state)): \(check.text)"))
        .accessibilityIdentifier("autopilot.guided.review.check.\(check.id)")
    }

    /// The check's status symbol (README-DS §13).
    private func mark(_ state: GuidedCheck.State) -> String {
        switch state {
        case .passed: StatusSymbol.done.symbol
        case .toConfirm: StatusSymbol.needsYou.symbol
        case .attention: StatusSymbol.error.symbol
        case .working: "ellipsis.circle"
        }
    }

    private func color(_ state: GuidedCheck.State) -> Color {
        switch state {
        case .passed: Palette.decrease
        case .toConfirm: Palette.warn
        case .attention: Palette.err
        case .working: Palette.label2
        }
    }

    private func label(_ state: GuidedCheck.State) -> String {
        switch state {
        case .passed: String(localized: "Passed")
        case .toConfirm: String(localized: "To confirm")
        case .attention: String(localized: "Needs a look")
        case .working: String(localized: "In progress")
        }
    }
}

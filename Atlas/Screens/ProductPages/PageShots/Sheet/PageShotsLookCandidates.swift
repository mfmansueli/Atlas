//
//  PageShotsLookCandidates.swift
//  Atlas
//

import SwiftUI

/// The stop a new look adds: the three looks Claude Code drew, each on the
/// page's first screenshot, and the one chosen.
struct PageShotsLookCandidates: View {
    @Bindable var flow: PageShotsFlow
    let source: PageShotsSource

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            status
            if !candidates.isEmpty {
                HStack(alignment: .top, spacing: Spacing.small) {
                    ForEach(candidates) { candidate in
                        card(candidate)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.shots.looks")
    }

    private var design: PageShotsDesign? { flow.run?.design }
    private var candidates: [PageShotsLookCandidate] { design?.candidates ?? [] }
    private var assistant: String { flow.run?.plan?.source ?? "Claude Code" }

    @ViewBuilder
    private var status: some View {
        let count = candidates.count
        let total = PageShotsDesign.candidateCount
        if design?.claudeRunID != nil, count < total {
            HStack(spacing: Spacing.small) {
                ProgressView().controlSize(.small)
                Text("\(assistant) is drawing · \(count) of \(total) ready")
                    .font(.subheadline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pages.shots.looks.drawing")
        } else if let problem = design?.problem {
            InlineMessage.warning(problem)
                .accessibilityIdentifier("pages.shots.looks.problem")
        } else if count > 0 {
            Text(design?.chosen == nil ? "Choose one to start." : "The set is made with the one outlined.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
        }
        if design?.claudeRunID == nil, count < total {
            Button(count == 0 ? "Ask for Three Looks" : "Ask Again") { Task { await flow.askForLooks() } }
                .controlSize(.small)
                .accessibilityIdentifier("pages.shots.looks.ask")
        }
    }

    private func card(_ candidate: PageShotsLookCandidate) -> some View {
        let isChosen = design?.chosenID == candidate.id
        return Button {
            flow.pick(lookID: candidate.id)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                PageShotsPreviewTile(
                    source: drawn(with: candidate), screens: screens, position: 0, locale: flow.run?.primaryLocale ?? source.primary,
                    displayType: .iPhone, height: 150
                )
                Text(candidate.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(candidate.rationale)
                    .font(.caption2)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.xSmall)
            .frame(width: 150 * PageShotsTile.aspect(.iPhone) + Spacing.xSmall * 2, alignment: .leading)
            .background(isChosen ? Palette.accent.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isChosen ? Palette.accent : Palette.separator, lineWidth: isChosen ? 2 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChosen ? [.isSelected] : [])
        .accessibilityIdentifier("pages.shots.looks.\(candidate.name)")
    }

    /// The plan's first screen, or the default set's first before the plan
    /// is in.
    private var screens: [PageShotsScreen] {
        flow.run?.plan?.screens ?? [PageShotsScreen(slot: 0, captions: [:])]
    }

    private func drawn(with candidate: PageShotsLookCandidate) -> PageShotsSource {
        var drawn = source
        drawn.lookTemplate = candidate.template
        drawn.recapture = flow.run?.recapture
        return drawn
    }
}

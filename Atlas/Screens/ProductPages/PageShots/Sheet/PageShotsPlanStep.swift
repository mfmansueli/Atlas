//
//  PageShotsPlanStep.swift
//  Atlas
//

import SwiftUI

/// Plan: the angle (the page's story, editable), the default set's screens
/// in the page's order with their new captions, the look, which languages
/// and devices get the page's own images, and who does what. Start
/// Autopilot lays the set out.
struct PageShotsPlanStep: View {
    @Bindable var flow: PageShotsFlow
    /// The set as it'll be made: the run's Look and captures.
    let source: PageShotsSource
    /// The default page's, for the Look's choices.
    let defaultSource: PageShotsSource

    @State private var angle = ""
    @FocusState private var isEditingAngle: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xLarge) {
                        angleSection
                        orderSection
                        PageShotsLookSection(flow: flow, source: defaultSource)
                    }
                    .padding(.horizontal, Spacing.xLarge)
                    .padding(.vertical, Spacing.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityIdentifier("pages.shots.planScroll")
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xLarge) {
                        PageShotsLanguagesSection(flow: flow, source: source)
                        PageShotsCapturesSection(flow: flow, source: source)
                        planSection
                    }
                    .padding(.horizontal, Spacing.xLarge)
                    .padding(.vertical, Spacing.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 320)
            }
            Divider()
            footer
                .padding(.horizontal, Spacing.xLarge)
                .padding(.vertical, Spacing.medium)
        }
        .onAppear { angle = flow.run?.plan?.angle ?? "" }
        .onChange(of: flow.run?.plan?.angle) { _, new in
            if !isEditingAngle { angle = new ?? "" }
        }
    }

    private var run: PageShotsRun? { flow.run }
    private var plan: PageShotsPlan? { run?.plan }
    private var assistant: String { plan?.source ?? "Claude Code" }

    // MARK: - Left

    private var angleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.small) {
                Text("The angle").font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if plan != nil { AssistantChip(name: assistant) }
            }
            if plan != nil {
                TextEditor(text: $angle)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.xSmall)
                    .frame(height: 54)
                    .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                    .focused($isEditingAngle)
                    .onChange(of: isEditingAngle) { _, editing in if !editing { flow.editAngle(angle) } }
                    .accessibilityLabel(Text("The angle"))
                    .accessibilityIdentifier("pages.shots.angle")
            } else {
                waiting
            }
            if let note = run?.note, !note.isEmpty {
                Text("Written from the page’s note: “\(note)” Change it, or leave it.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let reason = plan?.reason, !reason.isEmpty {
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pages.shots.reason")
            }
            if let confidence = plan?.layers?.confidence {
                HStack(spacing: Spacing.xSmall) {
                    HowSureMeter(confidence: confidence)
                    Text(confidence.word).font(.subheadline).foregroundStyle(Palette.label2)
                }
                .accessibilityElement(children: .combine)
            }
            if let details = plan?.layers?.details { SuggestionDetailsDisclosure(details: details) }
        }
    }

    /// The assistant is writing the plan, didn't send one, or Atlas copied
    /// its prompt.
    private var waiting: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if run?.stage == .planning {
                HStack(spacing: Spacing.small) {
                    ProgressView().controlSize(.small)
                    Text(flow.copiedPrompt == nil
                        ? String(localized: "\(assistant) is planning screen order and captions in every language.")
                        : String(localized: "Couldn’t start \(assistant). Paste the copied prompt into your assistant."))
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("pages.shots.planning")
            }
            if let problem = run?.problem {
                InlineMessage.warning(problem)
                    .accessibilityIdentifier("pages.shots.planProblem")
            }
            if run?.stage == .plan {
                Button("Ask Again") { Task { await flow.askForPlan() } }
                    .accessibilityIdentifier("pages.shots.askAgain")
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }

    @ViewBuilder
    private var orderSection: some View {
        if let plan {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("Screens, in this order").font(.body.weight(.semibold))
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: Spacing.small) {
                        ForEach(Array(plan.screens.enumerated()), id: \.offset) { position, screen in
                            VStack(spacing: 3) {
                                PageShotsPreviewTile(
                                    source: source, screens: plan.screens, position: position, locale: run?.primaryLocale ?? source.primary,
                                    displayType: .iPhone, height: 186
                                )
                                Text("\(position + 1) · \(source.slotName(screen.slot))")
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                if screen.slot != position {
                                    Text("was \(screen.slot + 1)")
                                        .font(.footnote)
                                        .foregroundStyle(Palette.label2)
                                }
                                if recapturedSlots.contains(screen.slot) {
                                    Text("captured again")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(Palette.accent)
                                }
                            }
                            .frame(width: 186 * PageShotsTile.aspect(.iPhone))
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("pages.shots.order.\(position + 1)")
                        }
                    }
                    .padding(.vertical, 2)
                }
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityIdentifier("pages.shots.order")
                Text(orderNote(plan))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func orderNote(_ plan: PageShotsPlan) -> String {
        let count = plan.screens.count
        let total = source.slotCount
        let moved = plan.screens.enumerated().contains { $0.offset != $0.element.slot }
        let note = if count != total {
            String(localized: "\(count) of the default page’s \(total) screens, reordered, with new captions.")
        } else if moved {
            String(localized: "The same \(count) screens as the default page, reordered, with new captions.")
        } else {
            String(localized: "The same \(count) screens as the default page, with other captions.")
        }
        let again = plan.screens.filter { recapturedSlots.contains($0.slot) }.count
        guard again > 0 else { return note }
        return again == 1
            ? note + " " + String(localized: "1 is captured again.")
            : note + " " + String(localized: "\(again) are captured again.")
    }

    private var recapturedSlots: Set<Int> { Set(run?.recapture?.slots ?? []) }

    // MARK: - Right

    private var planSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Plan").font(.body.weight(.semibold))
            planRow(
                title: String(localized: "Write the captions"),
                detail: plan == nil
                    ? String(localized: "For this page’s audience, in \(flow.languages.count) languages.")
                    : String(localized: "Ready in \(flow.readyLocales.count) of \(flow.languages.count) languages."),
                who: assistant
            )
            if run?.look.isClaudeDesign == true {
                planRow(
                    title: String(localized: "Draw three looks"),
                    detail: String(localized: "\(run?.design?.candidates.count ?? 0) of \(PageShotsDesign.candidateCount) ready. Choose one."),
                    who: assistant
                )
            }
            if let recapture = run?.recapture {
                planRow(
                    title: String(localized: "Capture screens again"),
                    detail: String(localized: "In the Simulator, at most \(PageShotsRecapture.maxScreens) screens. \(recapture.slots.count) so far."),
                    who: assistant
                )
            }
            planRow(
                title: String(localized: "Lay out \(run?.expectedCount ?? 0) screenshots"),
                detail: recapturedSlots.isEmpty
                    ? String(localized: "Uses the default page’s captures. No recapture.")
                    : String(localized: "Uses the default page’s captures; \(recapturedSlots.count) recaptured."),
                who: "Atlas"
            )
        }
    }

    private func planRow(title: String, detail: String, who: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            AssistantChip(name: who, monogram: who == "Atlas" ? "A" : nil)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: Spacing.medium) {
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("pages.shots.summary")
            Button("Cancel") { flow.cancel() }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("pages.shots.cancel")
            Button("Start Autopilot") {
                if isEditingAngle { flow.editAngle(angle) }
                flow.startAutopilot()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!flow.canStart)
            .accessibilityIdentifier("pages.shots.start")
        }
    }

    private var summary: String {
        let count = run?.expectedCount ?? 0
        if run?.design?.isReady == false { return String(localized: "Choose one of 3 looks.") }
        guard count > 0 else { return String(localized: "The default page’s screenshots don’t change.") }
        let minutes = max(1, Int((Double(count) * 1.5 / 60).rounded(.up)))
        return String(localized: "\(count) screenshots · about \(minutes) min · default page unchanged")
    }
}

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
    let source: PageShotsSource

    @State private var angle = ""
    @FocusState private var isEditingAngle: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xLarge) {
                        angleSection
                        orderSection
                        lookSection
                    }
                    .padding(.horizontal, Spacing.xLarge)
                    .padding(.vertical, Spacing.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xLarge) {
                        PageShotsLanguagesSection(flow: flow, source: source)
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
                Text("The angle").font(.headline)
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
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let reason = plan?.reason, !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pages.shots.reason")
            }
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
                        ? String(localized: "\(assistant) is planning the set: the order and a caption for each screen in every language.")
                        : String(localized: "Atlas couldn’t start \(assistant) here, so the prompt is copied. Paste it into your assistant."))
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
                Text("Screens, in this order").font(.headline)
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: Spacing.small) {
                        ForEach(Array(plan.screens.enumerated()), id: \.offset) { position, screen in
                            VStack(spacing: 3) {
                                PageShotsPreviewTile(
                                    source: source, screens: plan.screens, position: position, locale: run?.primaryLocale ?? source.primary,
                                    displayType: .iPhone, height: 186
                                )
                                Text("\(position + 1) · \(source.slotName(screen.slot))")
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                if screen.slot != position {
                                    Text("was \(screen.slot + 1)")
                                        .font(.caption2)
                                        .foregroundStyle(Palette.label2)
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
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func orderNote(_ plan: PageShotsPlan) -> String {
        let count = plan.screens.count
        let total = source.slotCount
        let moved = plan.screens.enumerated().contains { $0.offset != $0.element.slot }
        if count == total {
            return moved
                ? String(localized: "The same \(count) screens as the default page, in another order and with other captions.")
                : String(localized: "The same \(count) screens as the default page, with other captions.")
        }
        return String(localized: "\(count) of the default page’s \(total) screens, in this page’s order and with other captions.")
    }

    private var lookSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Look").font(.headline)
            HStack(alignment: .top, spacing: Spacing.small) {
                Image(systemName: "largecircle.fill.circle")
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("The same template as the default page").font(.callout)
                    Text(lookNote)
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pages.shots.look")
        }
    }

    private var lookNote: String {
        let name = run?.templateName ?? ""
        let app = flow.app.name
        return name.isEmpty
            ? String(localized: "The page looks like \(app), with a different story.")
            : String(localized: "\(name). The page looks like \(app), with a different story.")
    }

    // MARK: - Right

    private var planSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Plan").font(.headline)
            planRow(
                title: String(localized: "Write the captions"),
                detail: plan == nil
                    ? String(localized: "For this page’s audience, in \(flow.languages.count) languages.")
                    : String(localized: "Ready in \(flow.readyLocales.count) of \(flow.languages.count) languages."),
                who: assistant
            )
            planRow(
                title: String(localized: "Lay out \(run?.expectedCount ?? 0) screenshots"),
                detail: String(localized: "From the default page’s captures. Nothing is captured again."),
                who: "Atlas"
            )
        }
    }

    private func planRow(title: String, detail: String, who: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout)
                Text(detail)
                    .font(.caption)
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
                .font(.caption)
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
        guard count > 0 else { return String(localized: "The default page’s screenshots don’t change.") }
        let minutes = max(1, Int((Double(count) * 1.5 / 60).rounded(.up)))
        return String(localized: "\(count) screenshots for this page · about \(minutes) min · the default page’s screenshots don’t change")
    }
}

//
//  PageShotsCapturesSection.swift
//  Atlas
//

import SwiftUI

/// Capture Screens Again (board 52): off, the set is laid out from the
/// default page's captures; on, Claude Code runs the app in the Simulator
/// and captures the screens that should show something else for this page.
struct PageShotsCapturesSection: View {
    @Bindable var flow: PageShotsFlow
    let source: PageShotsSource

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Captures").font(.body.weight(.semibold))
            Toggle("Capture screens again", isOn: Binding(
                get: { flow.run?.recapture != nil },
                set: { isOn in Task { await flow.setRecapture(isOn) } }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .disabled(flow.run?.stage == .making)
            .accessibilityIdentifier("pages.shots.recapture")
            if let recapture = flow.run?.recapture {
                progress(recapture)
                ForEach(recapture.slots, id: \.self) { slot in
                    row(slot: slot, recapture: recapture)
                }
            } else {
                Text("""
                \(assistant) runs the app in the Simulator and captures the screens that should show something else for this \
                page. It takes longer. The default page’s captures don’t change.
                """)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.shots.captures")
    }

    private var assistant: String { flow.run?.plan?.source ?? "Claude Code" }

    @ViewBuilder
    private func progress(_ recapture: PageShotsRecapture) -> some View {
        if recapture.claudeRunID != nil {
            HStack(spacing: Spacing.small) {
                ProgressView().controlSize(.small)
                Text(recapture.captures.isEmpty
                    ? String(localized: "\(assistant) is capturing screens in the Simulator.")
                    : String(localized: "\(assistant) is capturing · \(recapture.slots.count) screens so far"))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pages.shots.captures.working")
        } else if let problem = recapture.problem {
            InlineMessage.warning(problem)
                .accessibilityIdentifier("pages.shots.captures.problem")
        }
        if recapture.claudeRunID == nil {
            Button(recapture.captures.isEmpty ? "Ask to Capture" : "Ask Again") { Task { await flow.askForCaptures() } }
                .controlSize(.regular)
                .accessibilityIdentifier("pages.shots.captures.ask")
        }
    }

    private func row(slot: Int, recapture: PageShotsRecapture) -> some View {
        let captures = recapture.captures.filter { $0.slot == slot }
        let languages = Array(Set(captures.map(\.locale))).sorted().map(ProductPageChangeBuilder.localeName).formatted(.list(type: .and))
        let devices = Array(Set(captures.map(\.displayType))).sorted { $0.rawValue < $1.rawValue }.map(\.shortTitle)
            .formatted(.list(type: .and))
        return HStack(alignment: .top, spacing: Spacing.small) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(slot + 1) · \(source.slotName(slot))").font(.callout)
                Text("\(languages) · \(devices)")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                if let notes = captures.last?.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Use the Default") { flow.forgetCaptures(slot: slot) }
                .controlSize(.regular)
                .accessibilityIdentifier("pages.shots.captures.default.\(slot + 1)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.shots.captures.screen.\(slot + 1)")
    }
}

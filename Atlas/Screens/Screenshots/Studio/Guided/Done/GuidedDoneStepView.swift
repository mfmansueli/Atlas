//
//  GuidedDoneStepView.swift
//  Atlas
//

import SwiftUI

/// Done: after Approve All, "Waiting in Review & Push" with Open Review &
/// Push…. The push goes only from Review & Push, with the person's other
/// changes: Done follows it in one line ("Pushing from Review & Push",
/// then "Sent to the App Store"), and its progress, failures and Try
/// Again stay in Review & Push, which Show Progress… and Open Review &
/// Push… open.
struct GuidedDoneStepView: View {
    @Bindable var studio: ScreenshotStudioModel
    let run: AutopilotRun
    @Environment(PushController.self) private var push: PushController?
    @Environment(WorkspaceNavigator.self) private var navigator: WorkspaceNavigator?

    var body: some View {
        let outcome = GuidedPushOutcome.make(
            images: imageRun.map { GuidedPushOutcome.Tally(total: $0.totalCount, done: $0.doneCount, isRunning: $0.isRunning) },
            extras: extrasRun.map { GuidedPushOutcome.Tally(total: $0.items.count, done: $0.doneCount, isRunning: $0.isRunning) },
            pushedFromSheet: run.guidedReview?.pushedAt != nil
        )
        VStack(spacing: Spacing.medium) {
            Spacer(minLength: 0)
            Image(systemName: outcome.symbol)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(outcome == .partly ? Palette.warnMark : Palette.accent, in: Circle())
                .accessibilityHidden(true)
            Text(outcome.title)
                .font(.title2.weight(.semibold))
                .accessibilityIdentifier("autopilot.guided.done.title")
            Text(outcome.detail ?? sentText)
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("autopilot.guided.done.text")
            if outcome.opensReviewPush {
                Button(outcome.reviewPushTitle) { studio.openReviewPush(navigator) }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("autopilot.guided.done.openReview")
            }
            Spacer(minLength: 0)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("autopilot.guided.done")
    }

    /// This app's image push, if it's the one going (or last gone).
    private var imageRun: ScreenshotPushRun? {
        guard let run = push?.screenshots.run, run.appIDs.contains(studio.app.id) else { return nil }
        return run
    }

    private var extrasRun: ExtrasPushRun? {
        guard let run = push?.screenshots.extras.run, run.items.contains(where: { $0.appID == studio.app.id }) else { return nil }
        return run
    }

    /// "12 screenshots, 2 App Previews and a header and search image in
    /// 15 languages are on App Store Connect. Template v5 is saved;
    /// everything is in the set’s history."
    private var sentText: String {
        let what = GuidedMakeSummary.pushed(run.plan) ?? String(localized: "The new files")
        var text = String(localized: "\(what) are on App Store Connect.")
        if let version = run.templateVersion, run.plan.makesScreenshots {
            text += " " + String(localized: "Template v\(version) is saved; everything is in the set’s history.")
        }
        return text + " " + String(localized: "Apple is processing them; the live page changes within minutes.")
    }
}

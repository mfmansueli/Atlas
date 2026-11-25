//
//  WatchDebugReportView.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// A plain report of one Look for Improvements check, for DEBUG scenes:
/// each app's findings with their fingerprint and verdict, why no run
/// starts, its kinds' backoff, and the prompt a run would start with.
/// Machine words only (`Text(verbatim:)`): the screens wait for the
/// boards.
struct WatchDebugReportView: View {
    let center: WatchCenter
    let plan: WatchPlan

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xLarge) {
                Text(verbatim: "Look for Improvements · \(plan.date.formatted(date: .abbreviated, time: .shortened))")
                    .atlasTextStyle(.title2)
                ForEach(plan.apps) { app in
                    appReport(app)
                }
            }
            .padding(Spacing.xLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .textSelection(.enabled)
        .accessibilityIdentifier("watch.debug")
    }

    private func appReport(_ app: WatchPlan.App) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(verbatim: app.appName).atlasTextStyle(.headline)
            ForEach(app.decisions) { decision in
                VStack(alignment: .leading, spacing: Spacing.tiny) {
                    Text(verbatim: "\(decision.verdict.key) · \(decision.signal.fingerprint)").atlasTextStyle(.callout)
                    Text(verbatim: decision.signal.summary).atlasTextStyle(.subheadline).foregroundStyle(Palette.label2)
                }
            }
            if app.decisions.isEmpty {
                Text(verbatim: "No findings").atlasTextStyle(.subheadline).foregroundStyle(Palette.label2)
            }
            Text(verbatim: "Run: \(app.startsRun ? "starts" : app.refusal?.key ?? "nothing to send")").atlasTextStyle(.callout)
            Text(verbatim: kinds(app.appID)).atlasTextStyle(.footnote).foregroundStyle(Palette.label2)
            if let prompt = app.prompt {
                Text(verbatim: prompt)
                    .atlasTextStyle(.footnote)
                    .monospaced()
                    .padding(Spacing.medium)
                    .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("watch.debug.\(app.appID)")
    }

    /// Each kind that isn't at its defaults: paused, silenced, asking, ×N.
    private func kinds(_ appID: StoreApp.ID) -> String {
        let archive = center.archive(for: appID)
        let lines = WatchSignalKind.allCases.compactMap { kind -> String? in
            let stats = archive.stats(for: kind)
            var flags: [String] = []
            if stats.isSilenced { flags.append("silenced") }
            if stats.isPaused { flags.append("paused") }
            if stats.asksKeepSuggesting { flags.append("asks Keep Suggesting?") }
            if stats.intervalMultiplier > 1 { flags.append("interval ×\(stats.intervalMultiplier)") }
            return flags.isEmpty ? nil : "\(kind.rawValue): \(flags.joined(separator: ", "))"
        }
        let runs = "\(archive.history.count) runs in History"
        return ([runs] + lines).joined(separator: " · ")
    }
}
#endif

//
//  BillingView.swift
//  Atlas
//

import SwiftUI

/// Analytics → Subscriptions → Billing and Plans: subscribers Apple couldn't
/// charge, Billing Grace Period, plan changes and why people canceled.
struct BillingView: View {
    let report: LifecycleReport?
    let gracePeriod: GracePeriodSetting?
    let appName: String
    let onTurnOn: (GracePeriodSetting.Duration) async throws -> Void

    @State private var isConfirming = false
    @State private var duration = GracePeriodSetting.Duration.sixteenDays
    @State private var isTurningOn = false
    @State private var failure: AppleErrorCopy?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if let report {
                    content(report)
                } else {
                    ContentUnavailableView(
                        "No billing numbers yet", systemImage: "creditcard",
                        description: Text("Apple is still preparing the subscription event report for \(appName).")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xLarge)
                }
            }
            .padding(.bottom, Spacing.xLarge)
        }
        .accessibilityIdentifier("analytics.billing")
        .sheet(isPresented: $isConfirming) { confirmation }
    }

    @ViewBuilder
    private func content(_ report: LifecycleReport) -> some View {
        if gracePeriod?.isOn == false, report.lost > 0 {
            AnalyticsNotice(
                tone: .warning,
                text: String(localized: "\(AnalyticsText.count(report.lost)) subscribers left in \(report.period.length) days over failed charges. Billing Grace Period, now off, keeps them while Apple retries."),
                primary: (String(localized: "Turn On Billing Grace Period…"), { isConfirming = true }),
                identifier: "analytics.billing.gracePeriodNotice"
            )
        }
        if let failure { ErrorCopyMessage(copy: failure) }
        AdaptiveGridLayout(minimumWidth: 180, spacing: Spacing.medium) {
            AnalyticsStat(
                label: String(localized: "Couldn’t be charged"), value: AnalyticsText.count(report.couldNotCharge),
                note: String(localized: "Entered billing retry or grace period")
            )
            AnalyticsStat(
                label: String(localized: "Recovered"), value: AnalyticsText.count(report.recovered),
                note: report.recoveredShare.map { String(localized: "\(AnalyticsText.wholePercent($0)) paid again") } ?? ""
            )
            AnalyticsStat(
                label: String(localized: "Lost"), value: AnalyticsText.count(report.lost),
                note: report.lostShare.map { String(localized: "\(AnalyticsText.wholePercent($0)) of cancellations") } ?? "",
                valueColor: report.lost > 0 ? Palette.err : Palette.label
            )
            AnalyticsStat(
                label: String(localized: "Billing Grace Period"),
                value: gracePeriod.map { $0.isOn ? String(localized: "On") : String(localized: "Off") } ?? "—",
                note: gracePeriod.flatMap { $0.isOn ? $0.duration?.title : nil } ?? (gracePeriod == nil ? String(localized: "Not read") : ""),
                identifier: "analytics.billing.gracePeriod"
            )
        }
        AdaptiveGridLayout(minimumWidth: 340, spacing: Spacing.medium) {
            AnalyticsBox(title: String(localized: "Plan changes"), trailing: AnalyticsText.count(report.planChanges.reduce(0) { $0 + $1.count })) {
                ForEach(report.planChanges) { ShareBarRow(name: $0.name, count: $0.count, share: $0.share) }
                Spacer(minLength: Spacing.xSmall).frame(height: Spacing.xSmall)
            }
            AnalyticsBox(title: String(localized: "Why people canceled"), trailing: AnalyticsText.count(report.cancellations)) {
                ForEach(report.cancelReasons.filter { $0.count > 0 }) { ShareBarRow(name: $0.name, detail: $0.detail, count: $0.count, share: $0.share) }
                Spacer(minLength: Spacing.xSmall).frame(height: Spacing.xSmall)
            }
        }
        if let grace = report.inGracePeriod, let retry = report.inBillingRetry {
            Text("Right now: \(AnalyticsText.count(grace)) in a grace period, \(AnalyticsText.count(retry)) in billing retry.")
                .font(.callout).foregroundStyle(Palette.label2)
        }
        Text("From Apple’s subscription event and state reports: every subscriber. Apple retries a failed charge for up to 60 days.")
            .font(.subheadline).foregroundStyle(Palette.label2).lineLimit(2)
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Turn On Billing Grace Period for \(appName)?").font(.title3.weight(.semibold))
            Text("""
            Subscribers keep access while Apple retries failed renewals, for every subscription in production, from \
            the next failed renewal. Turn it off in App Store Connect.
            """)
            .lineLimit(5)
            Picker("Grace period", selection: $duration) {
                ForEach(GracePeriodSetting.Duration.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("analytics.billing.duration")
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { isConfirming = false }
                    .keyboardShortcut(.cancelAction)
                Button("Turn On") {
                    Task { await turnOn() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isTurningOn)
                .accessibilityIdentifier("analytics.billing.turnOn")
            }
        }
        .padding(Spacing.xLarge)
        .frame(width: 440)
    }

    private func turnOn() async {
        isTurningOn = true
        defer { isTurningOn = false }
        do {
            try await onTurnOn(duration)
            failure = nil
            isConfirming = false
        } catch {
            failure = AppleErrorCopy(String(localized: "Billing Grace Period wasn’t turned on.", comment: "kind:error"), error: error)
            isConfirming = false
        }
    }
}

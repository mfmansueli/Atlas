//
//  FunnelMoreView.swift
//  Atlas
//

import SwiftUI

/// Around the funnel: the app's page on the web (before the store), and
/// what people do after the download (a sample).
struct FunnelMoreView: View {
    let afterDownload: AfterDownloadNumbers?
    let webPreview: WebPreviewReport?

    var body: some View {
        AdaptiveGridLayout(minimumWidth: 340, spacing: Spacing.medium) {
            if let webPreview {
                AnalyticsBox(title: String(localized: "On the web"), trailing: String(localized: "apps.apple.com")) {
                    HStack(spacing: Spacing.large) {
                        figure(String(localized: "Page views"), AnalyticsText.count(webPreview.pageViews))
                        figure(String(localized: "Taps"), AnalyticsText.count(webPreview.taps))
                    }
                    .padding(.horizontal, Spacing.medium)
                    ForEach(webPreview.byEngagement.prefix(4)) { tap in
                        ShareBarRow(name: tap.name, count: tap.count, share: tap.share)
                    }
                    Spacer(minLength: Spacing.xSmall).frame(height: Spacing.xSmall)
                }
                .accessibilityIdentifier("analytics.funnel.web")
            }
            if let afterDownload {
                AnalyticsBox(title: String(localized: "After the download"), trailing: String(localized: "a sample")) {
                    AdaptiveGridLayout(minimumWidth: 110, spacing: Spacing.medium) {
                        figure(String(localized: "Installs"), AnalyticsText.count(afterDownload.installs))
                        figure(String(localized: "Deleted in 30 days"), afterDownload.deletedWithin30.text)
                        figure(
                            String(localized: "Sessions a week"),
                            afterDownload.sessionsPerWeek.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—"
                        )
                        figure(String(localized: "Added a widget"), afterDownload.widgetDevices > 0 ? afterDownload.widgetShare.text : "—")
                    }
                    .padding(.horizontal, Spacing.medium)
                    Text("From people who share analytics with developers.")
                        .font(.subheadline).foregroundStyle(Palette.label2)
                        .padding(.horizontal, Spacing.medium)
                }
                .accessibilityIdentifier("analytics.funnel.afterDownload")
            }
        }
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.subheadline).foregroundStyle(Palette.label2).lineLimit(1)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

//
//  PriceTestCard.swift
//  Atlas
//

import SwiftUI

/// A price test in Results (board 76): queued (`pt-rp`), "Day 9 of 28"
/// with its menu (`pt-run`), waiting for the result, the verdict with how
/// sure and Details (`pt-ready`, `pt-ready-det`, `pt-worse`, `pt-few`),
/// or kept (`pt-kept`). No motion while it runs.
struct PriceTestCard: View {
    let test: PriceTest
    let phase: PriceTestPhase
    let isEndQueued: Bool
    let isDetailsOpen: Bool
    var onRemove: () -> Void = {}
    var onReview: () -> Void = {}
    var onShowCountries: () -> Void = {}
    var onEndEarly: () -> Void = {}
    var onToggleDetails: () -> Void = {}
    var onDone: () -> Void = {}
    var onKeep: () -> Void = {}
    var onTestAgain: () -> Void = {}

    var body: some View {
        Card {
            header
            content
        }
        .accessibilityIdentifier("priceTest.card.\(test.id)")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.xSmall) {
            Text(test.title)
                .atlasTextStyle(.headline)
                .lineLimit(1)
            statusPill
            Spacer(minLength: Spacing.small)
            if case .running = phase { menu }
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        switch phase {
        case .queued:
            Pill(text: String(localized: "Not pushed", comment: "kind:pill"), style: .accent).fixedSize()
        case let .running(day):
            Pill(text: PriceTestText.day(day)).fixedSize()
                .accessibilityIdentifier("priceTest.card.day")
        case .waitingForResult:
            Pill(text: String(localized: "Result in 1–2 days", comment: "kind:pill")).fixedSize()
        case let .ready(result):
            Pill(text: result.verdict.title, style: result.verdict == .worse ? .warning : .neutral).fixedSize()
                .accessibilityIdentifier("priceTest.card.verdict")
            if let howSure = result.howSure {
                HowSureMeter(confidence: howSure, detail: result.rangeText)
                Text(howSure.word)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
        case .kept:
            Pill(text: String(localized: "Kept", comment: "kind:pill")).fixedSize()
        case .ended, .done:
            EmptyView()
        }
    }

    private var menu: some View {
        Menu {
            Button(String(localized: "Show Countries", comment: "kind:menu-item"), action: onShowCountries)
            Button(String(localized: "End Test Early…", comment: "kind:menu-item"), action: onEndEarly)
                .disabled(isEndQueued)
        } label: {
            Image(systemName: "ellipsis.circle")
                .accessibilityLabel(Text("More", comment: "kind:accessibility-label"))
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityIdentifier("priceTest.card.menu")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .queued:
            line(String(localized: "Waits in Review & Push. It starts when you push and ends 28 days later.", comment: "kind:status"))
            facts
            buttons {
                Button(String(localized: "Remove", comment: "kind:button"), action: onRemove)
                    .secondaryButton()
                    .accessibilityIdentifier("priceTest.card.remove")
                Button(String(localized: "Review & Push", comment: "kind:button"), action: onReview)
                    .primaryButton()
                    .accessibilityIdentifier("priceTest.card.review")
            }
        case .running:
            line(runningLine)
            facts
            buttons {
                Button(String(localized: "Show Countries", comment: "kind:button"), action: onShowCountries)
                    .secondaryButton()
                    .accessibilityIdentifier("priceTest.card.showCountries")
            }
        case .waitingForResult:
            line(String(
                localized: "The old prices are back. The result arrives when Apple’s reports cover the 28 days, in 1–2 days.",
                comment: "kind:status"
            ))
            facts
        case let .ready(result):
            ready(result)
        case .kept:
            line(String(localized: "The test prices wait in Review & Push as a price change. Results compares it like any other.", comment: "kind:status"))
            buttons {
                Button(String(localized: "Done", comment: "kind:button"), action: onDone)
                    .secondaryButton()
                    .accessibilityIdentifier("priceTest.card.done")
            }
        case .ended, .done:
            EmptyView()
        }
    }

    private var runningLine: String {
        if isEndQueued {
            return String(localized: "Ending the test waits in Review & Push. The old prices come back when you push.", comment: "kind:status")
        }
        let ends = test.endsOn.map(PriceTestText.shortDate) ?? ""
        return String(
            localized: "No result before the end: early numbers swing. Ends \(ends), then the old prices come back.",
            comment: "kind:status"
        )
    }

    /// Test price and Compared with.
    private var facts: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            PriceTestFactRow(label: String(localized: "Test price", comment: "kind:label"), value: testPrice)
            PriceTestFactRow(label: String(localized: "Compared with", comment: "kind:label"), value: comparedWith)
        }
    }

    /// "−20% in 14 countries · Germany €39.99 → €31.99, …".
    private var testPrice: String {
        let examples = PriceTestText.examples(test.countries)
        return String(localized: "\(test.step.title) in \(test.countries.count) countries · \(examples)", comment: "kind:label")
    }

    private var comparedWith: String {
        guard let control = test.control else {
            return String(localized: "No comparison: before against during only", comment: "kind:label")
        }
        return String(localized: "\(control.title), price unchanged", comment: "kind:label")
    }

    // MARK: - Result

    @ViewBuilder
    private func ready(_ result: PriceTestResult) -> some View {
        line(verdictLine(result))
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            let windows = result.windows
            PriceTestFactRow(
                label: String(localized: "Page view → start", comment: "kind:label"),
                value: "\(rate(windows.testBefore)) → \(rate(windows.testDuring))",
                isProminent: true
            )
            PriceTestFactRow(
                label: String(localized: "Proceeds, 28 days", comment: "kind:label"),
                value: "\(CurrencyFormat.usd.formatWhole(windows.testBefore.proceeds)) → \(CurrencyFormat.usd.formatWhole(windows.testDuring.proceeds))"
            )
            if let control = test.control, let before = windows.controlBefore, let during = windows.controlDuring {
                PriceTestFactRow(
                    label: String(localized: "\(control.title) (comparison)", comment: "kind:label"),
                    value: "\(rate(before)) → \(rate(during))"
                )
            }
        }
        if isDetailsOpen { PriceTestResultDetails(test: test, result: result) }
        buttons {
            Button(detailsTitle, action: onToggleDetails)
                .plainButton()
                .accessibilityIdentifier("priceTest.card.details")
            Spacer()
            Button(String(localized: "Done", comment: "kind:button"), action: onDone)
                .secondaryButton()
                .accessibilityIdentifier("priceTest.card.done")
            switch result.verdict {
            case .better:
                Button(String(localized: "Keep Test Prices…", comment: "kind:button"), action: onKeep)
                    .primaryButton()
                    .accessibilityIdentifier("priceTest.card.keep")
            case .tooLittleData:
                Button(String(localized: "Test Again…", comment: "kind:button"), action: onTestAgain)
                    .secondaryButton()
                    .accessibilityIdentifier("priceTest.card.testAgain")
            case .aboutTheSame, .worse:
                EmptyView()
            }
        }
    }

    /// "Page view → start +1.8 points against Asia Pacific." The range is
    /// in Details.
    private func verdictLine(_ result: PriceTestResult) -> String {
        if result.verdict == .tooLittleData {
            return String(localized: "Too few people in the 28 days to tell what the price did.", comment: "kind:status")
        }
        guard let control = test.control else {
            return String(localized: "Page view → start \(result.pointsText), before against during.", comment: "kind:status")
        }
        return String(localized: "Page view → start \(result.pointsText) against \(control.title).", comment: "kind:status")
    }

    private var detailsTitle: String {
        isDetailsOpen ? String(localized: "Hide Details", comment: "kind:button") : String(localized: "Details", comment: "kind:button")
    }

    private func rate(_ signal: SalesSignal) -> String {
        signal.conversion.map { PricingText.percent($0, places: 1) } ?? "—"
    }

    // MARK: - Parts

    private func line(_ text: String) -> some View {
        Text(text)
            .atlasTextStyle(.callout)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func buttons(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: Spacing.small) {
            Spacer(minLength: 0)
            content()
        }
        .controlSize(.regular)
    }
}

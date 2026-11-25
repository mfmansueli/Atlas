//
//  PriceDataSettingsSection.swift
//  Atlas
//

import SwiftUI

/// Settings → Pricing → Price data (board 76): the bundled price indexes
/// by source and edition, and the exchange rates' source and day with
/// Update Now, which fetches them whether or not a day has passed. A failed
/// update keeps the rates Atlas has and says so in amber; nothing animates
/// (it isn't the assistant at work).
struct PriceDataSettingsSection: View {
    private let store: ExchangeRateStore
    @State private var snapshot = try? PriceIndexSnapshot.bundled()
    @State private var rates: ExchangeRates
    @State private var update: UpdateState

    private enum UpdateState: Equatable {
        case idle
        case updating
        case failed(AppleErrorCopy)
    }

    /// `failure` opens on a failed update (its DEBUG scene).
    init(store: ExchangeRateStore = .shared, failure: AppleErrorCopy? = nil) {
        self.store = store
        _rates = State(initialValue: store.rates)
        _update = State(initialValue: failure.map(UpdateState.failed) ?? .idle)
    }

    var body: some View {
        let summary = PriceDataSummary.make(snapshot: snapshot, rates: rates)
        Section(String(localized: "Price data", comment: "kind:section-title")) {
            LabeledContent {
                VStack(alignment: .trailing, spacing: Spacing.tiny) {
                    ForEach(summary.indexes, id: \.self) { index in
                        Text(index)
                            .foregroundStyle(Palette.label2)
                    }
                }
            } label: {
                label(String(localized: "Price indexes", comment: "kind:label"), caption: Text(summary.snapshotLine))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.priceIndexes")
            LabeledContent {
                Button(update == .updating
                    ? String(localized: "Updating…", comment: "kind:button")
                    : String(localized: "Update Now", comment: "kind:button"))
                {
                    Task { await updateNow() }
                }
                .disabled(update == .updating)
                .accessibilityIdentifier("settings.exchangeRates.update")
            } label: {
                label(String(localized: "Exchange rates", comment: "kind:label"), caption: ratesCaption(summary))
            }
            .accessibilityIdentifier("settings.exchangeRates")
            if case let .failed(copy) = update {
                InlineMessage.warning(copy.summary)
                    .help(copy.details.map { Text(verbatim: $0) } ?? Text(verbatim: copy.summary))
                    .accessibilityIdentifier("settings.exchangeRates.error")
            }
            if summary.isApproximate {
                Text(String(
                    localized: """
                    The bundled values are approximate sample data, not the publishers’ figures. New editions arrive with app \
                    updates.
                    """,
                    comment: "kind:hint"
                ))
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func label(_ title: String, caption: Text) -> some View {
        VStack(alignment: .leading, spacing: Spacing.tiny) {
            Text(title)
            caption
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The rates line, linked to the provider as its terms ask.
    private func ratesCaption(_ summary: PriceDataSummary) -> Text {
        guard let url = summary.ratesURL else { return Text(summary.ratesLine) }
        var line = AttributedString(summary.ratesLine)
        line.link = url
        return Text(line)
    }

    private func updateNow() async {
        update = .updating
        do {
            rates = try await store.refreshNow()
            update = .idle
        } catch {
            update = .failed(AppleErrorCopy(String(localized: "Exchange rates didn’t update.", comment: "kind:error"), error: error))
        }
    }
}

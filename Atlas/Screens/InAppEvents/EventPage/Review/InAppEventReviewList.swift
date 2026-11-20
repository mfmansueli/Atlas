//
//  InAppEventReviewList.swift
//  Atlas
//

import SwiftUI

/// "Before App Review": what App Store Connect still needs on a draft
/// event, one line each with a way to fix it here (or where to, when Atlas
/// can't), and what already waits in Review & Push. Calm: it's a to-do
/// list, not an error. Under the needs, warnings about App Review's time
/// (the card or the start within two days), which never block.
struct InAppEventReviewList: View {
    @Bindable var viewModel: InAppEventsViewModel
    let event: InAppEvent
    let items: [InAppEventReviewItem]
    var warnings: [InAppEventReviewWarning] = []
    let actions: EventArtworkPanelActions

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Label("Before App Review", systemImage: "checklist")
                .font(.callout.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    Image(systemName: symbol(item))
                        .foregroundStyle(item.state == .missing ? Palette.label2 : Palette.positive)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.text)
                            .fixedSize(horizontal: false, vertical: true)
                        if let state = item.stateText {
                            Text(state).font(.caption).foregroundStyle(Palette.label2)
                        } else if let detail = item.detail {
                            Text(detail).font(.caption).foregroundStyle(Palette.label2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if item.state == .missing { fix(item) }
                }
                .font(.callout)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("events.review.\(item.id)")
            }
            ForEach(warnings) { warning in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.warning)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(warning.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("events.review.warning.\(warning.id).text")
                        if let detail = warning.detail {
                            Text(detail).font(.caption).foregroundStyle(Palette.label2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let date = warning.suggestedDates[.publishStart] {
                        Button(InAppEventsViewModel.showFromTitle(date)) { viewModel.applySuggestedDates(warning.suggestedDates, of: event) }
                            .controlSize(.small)
                            .accessibilityIdentifier("events.review.warning.\(warning.id).fix")
                    } else if viewModel.datesEditProblem(of: event) == nil {
                        Button("Change Dates…") { viewModel.focusedDateField = warning.warning.field }
                            .controlSize(.small)
                            .accessibilityIdentifier("events.review.warning.\(warning.id).fix")
                    }
                }
                .font(.callout)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("events.review.warning.\(warning.id)")
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.review")
    }

    private func symbol(_ item: InAppEventReviewItem) -> String {
        switch item.state {
        case .missing: "circle"
        case .queued: "clock"
        case .suggested: "sparkles"
        }
    }

    @ViewBuilder
    private func fix(_ item: InAppEventReviewItem) -> some View {
        switch item.kind {
        case .linkNotClaimed:
            InAppEventDeepLinkAskButton(
                app: viewModel.app, event: event, deepLink: viewModel.deepLink(of: event), kind: .makeItWork,
                identifier: "events.review.linkNotClaimed.fix"
            )
            .controlSize(.small)
        case let .need(need):
            switch need {
            case .deepLink:
                fixButton(String(localized: "Add Deep Link"), item) { viewModel.focusedDetail = .deepLink }
            case .primaryLocale, .purpose:
                fixButton(String(localized: "Choose…"), item) { viewModel.focusedDetail = need.detail }
            case .primaryTexts, .languageTexts:
                fixButton(String(localized: "Write It"), item) { viewModel.showLanguage(for: need, of: event) }
            case .card, .details:
                fixButton(String(localized: "Make the Artwork…"), item) { actions.make() }
            case .dates, .eventEndBeforeStart, .eventTooShort, .eventTooLong, .publishStartAfterEventStart, .publishStartTooEarly, .eventStartPassed,
                 .publishStartPassed:
                dateFix(item, need: need)
            }
        }
    }

    /// The "Shows from" that fixes it, else Fix… on the date to change;
    /// nothing when Atlas can't change the event's dates.
    @ViewBuilder
    private func dateFix(_ item: InAppEventReviewItem, need: InAppEventReviewNeed) -> some View {
        if viewModel.datesEditProblem(of: event) == nil {
            if let date = item.suggestedDates[.publishStart] {
                fixButton(InAppEventsViewModel.showFromTitle(date), item) { viewModel.applySuggestedDates(item.suggestedDates, of: event) }
                Button("Fix…") { viewModel.focusedDateField = need.dateField }
                    .controlSize(.small)
                    .accessibilityIdentifier("events.review.\(item.id).change")
            } else {
                fixButton(String(localized: "Fix…"), item) { viewModel.focusedDateField = need.dateField }
            }
        }
    }

    private func fixButton(_ title: String, _ item: InAppEventReviewItem, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .controlSize(.small)
            .accessibilityIdentifier("events.review.\(item.id).fix")
    }
}

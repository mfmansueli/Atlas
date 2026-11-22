//
//  InAppEventDatesSection.swift
//  Atlas
//

import SwiftUI

/// The Details card's dates for a draft: "Shows from", "Starts" and
/// "Ends", with date and time in the person's time zone (named under
/// them). Each edit waits in Review & Push as one change, with Undo per
/// date; an assistant's dates wait for Accept, and when the person queued
/// dates of their own, beside them with Accept and Dismiss. What breaks Apple's rules
/// shows under them, with the "Shows from" that fixes it. When Atlas
/// can't send dates (it doesn't know the event's territories), they're
/// shown as text with why.
struct InAppEventDatesSection: View {
    @Bindable var viewModel: InAppEventsViewModel
    let event: InAppEvent

    @FocusState private var focus: InAppEventDateField?

    var body: some View {
        let editProblem = viewModel.datesEditProblem(of: event)
        let dates = viewModel.dates(of: event)
        let format = InAppEventDateText.current
        VStack(alignment: .leading, spacing: Spacing.small) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.small) {
                ForEach(InAppEventDateField.allCases) { field in
                    GridRow {
                        Text(field.title)
                            .foregroundStyle(Palette.label2)
                            .frame(width: 150, alignment: .leading)
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                            if let dates, editProblem == nil {
                                DatePicker(
                                    field.title,
                                    selection: Binding { dates[field] } set: { viewModel.setDate(field, to: $0, of: event) },
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .labelsHidden()
                                .fixedSize()
                                .focused($focus, equals: field)
                                .accessibilityIdentifier("events.details.dates.\(field.rawValue)")
                            } else {
                                Text(dates.map { format.date($0[field]) } ?? String(localized: "Not set"))
                                    .accessibilityIdentifier("events.details.dates.\(field.rawValue)")
                            }
                            pendingControls(field)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if let suggested = viewModel.suggestedDates(of: event), let yours = dates {
                InAppEventDatesSuggestionView(
                    yours: yours, suggested: suggested.dates, alternative: suggested.alternative, format: format,
                    onDismiss: { viewModel.dismissSuggestedDates(of: event) }, onAccept: { viewModel.acceptSuggestedDates(of: event) }
                )
            }
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text("Times in your time zone, \(format.zoneName).")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("events.details.dates.zone")
                if let editProblem {
                    Text(editProblem)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("events.details.dates.cantChange")
                }
                ForEach(viewModel.dateProblems(of: event), id: \.self) { problem in
                    InlineMessage.error(problem)
                        .font(.subheadline)
                        .accessibilityIdentifier("events.details.dates.problem")
                }
                if let suggestion = viewModel.suggestedPublishStart(of: event) {
                    Button(InAppEventsViewModel.showFromTitle(suggestion)) {
                        viewModel.applySuggestedDates([.publishStart: suggestion], of: event)
                    }
                    .controlSize(.small)
                    .accessibilityIdentifier("events.details.dates.suggestion")
                }
                suggestionControls
            }
            .padding(.leading, 150 + Spacing.medium)
        }
        .onChange(of: viewModel.focusedDateField) { takeFocus() }
        .onAppear { takeFocus() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.details.dates")
    }

    /// "Not pushed" with Undo, on a date the person changed; "Suggested"
    /// on one an assistant did.
    @ViewBuilder
    private func pendingControls(_ field: InAppEventDateField) -> some View {
        if viewModel.isDatePending(field, of: event), let change = viewModel.queuedDates(of: event) {
            if change.awaitingAcceptance != nil {
                // The badge's purple: its text color is for text on the badge.
                Text("Suggested by \(change.source.title)")
                    .font(.subheadline)
                    .foregroundStyle(Palette.suggestionBadge)
            } else {
                Text("Not pushed")
                    .font(.subheadline)
                    .foregroundStyle(Palette.unsaved)
                    .accessibilityIdentifier("events.details.dates.\(field.rawValue).pending")
                Button {
                    viewModel.revertDate(field, of: event)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Undo: App Store Connect’s date again")
                .accessibilityLabel("Undo")
                .accessibilityIdentifier("events.details.dates.\(field.rawValue).undo")
            }
        }
    }

    /// Accept and Dismiss for an assistant's dates, once for all three.
    @ViewBuilder
    private var suggestionControls: some View {
        if let change = viewModel.queuedDates(of: event), change.awaitingAcceptance != nil {
            HStack(spacing: Spacing.small) {
                if let note = change.groupNote, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Accept Dates") { viewModel.acceptDates(of: event) }
                    .accessibilityIdentifier("events.details.dates.accept")
                Button("Dismiss") { viewModel.revertDates(of: event) }
                    .accessibilityIdentifier("events.details.dates.dismiss")
            }
            .controlSize(.small)
        }
    }

    private func takeFocus() {
        guard let field = viewModel.focusedDateField else { return }
        viewModel.focusedDateField = nil
        if viewModel.datesEditProblem(of: event) == nil { focus = field }
    }
}

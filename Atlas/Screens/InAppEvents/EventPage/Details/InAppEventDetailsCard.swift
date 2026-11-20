//
//  InAppEventDetailsCard.swift
//  Atlas
//

import SwiftUI

/// The event's deep link, purpose, priority and primary language, and a
/// draft's dates (`InAppEventDatesSection`): edited here while it's a
/// draft, each change waiting in Review & Push; an assistant's suggestion
/// waits for Accept. Under the deep link, whether the app opens it.
struct InAppEventDetailsCard: View {
    @Bindable var viewModel: InAppEventsViewModel
    let event: InAppEvent

    @State private var deepLinkText = ""
    @FocusState private var focus: InAppEventDetail?

    private var isEditable: Bool { event.state.isEditable }

    var body: some View {
        Card {
            Text("Details")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.small) {
                row(.deepLink) { deepLinkField }
                row(.purpose) { purposePicker }
                row(.priority) { priorityPicker }
                row(.primaryLocale) { languagePicker }
            }
            .font(.callout)
            if isEditable {
                InAppEventDatesSection(viewModel: viewModel, event: event)
                    .font(.callout)
            }
        }
        .onAppear { syncDeepLink() }
        .onChange(of: viewModel.deepLink(of: event)) { if focus != .deepLink { syncDeepLink() } }
        .onChange(of: event.id) { syncDeepLink() }
        .onChange(of: focus) { old, new in
            if old == .deepLink, new != .deepLink { commitDeepLink() }
        }
        .onChange(of: viewModel.focusedDetail) { takeFocus() }
        .onAppear { takeFocus() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.details")
    }

    // MARK: - Rows

    private func row(_ detail: InAppEventDetail, @ViewBuilder control: () -> some View) -> some View {
        GridRow {
            Text(detail.title)
                .foregroundStyle(Palette.label2)
                .frame(width: 150, alignment: .leading)
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    control()
                    pendingControls(detail)
                }
                if detail == .deepLink {
                    if let problem = viewModel.deepLinkProblem(deepLinkText) {
                        InlineMessage.error(problem)
                            .font(.caption)
                            .accessibilityIdentifier("events.details.deepLink.problem")
                    } else if isEditable, deepLinkText.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Needed before App Review. \(InAppEventDeepLink.example(appName: viewModel.app.name))")
                            .font(.caption)
                            .foregroundStyle(Palette.label2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("events.details.deepLink.note")
                    }
                    if viewModel.deepLink(of: event) != nil {
                        InAppEventDeepLinkCheckView(viewModel: viewModel, event: event)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// "Not pushed" with Undo for the person's change; Accept and Dismiss
    /// for an assistant's.
    @ViewBuilder
    private func pendingControls(_ detail: InAppEventDetail) -> some View {
        if let change = viewModel.queuedDetail(detail, of: event) {
            if change.awaitingAcceptance != nil {
                // The badge's purple: its text color is for text on the badge.
                Text("Suggested by \(change.source.title)")
                    .font(.caption)
                    .foregroundStyle(Palette.suggestionBadge)
                Button("Accept") { viewModel.acceptDetail(detail, of: event) }
                    .controlSize(.small)
                    .accessibilityIdentifier("events.details.\(detail.rawValue).accept")
                Button("Dismiss") { viewModel.revertDetail(detail, of: event) }
                    .controlSize(.small)
                    .accessibilityIdentifier("events.details.\(detail.rawValue).dismiss")
            } else {
                Text("Not pushed")
                    .font(.caption)
                    .foregroundStyle(Palette.unsaved)
                    .accessibilityIdentifier("events.details.\(detail.rawValue).pending")
                Button {
                    viewModel.revertDetail(detail, of: event)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Undo: App Store Connect’s \(detail.title.lowercased()) again")
                .accessibilityLabel("Undo")
                .accessibilityIdentifier("events.details.\(detail.rawValue).undo")
            }
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var deepLinkField: some View {
        if isEditable {
            TextField(
                "Deep link",
                text: $deepLinkText,
                prompt: Text(verbatim: "\(InAppEventDeepLink.slug(viewModel.app.name))://event")
            )
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .focused($focus, equals: .deepLink)
            .onSubmit { commitDeepLink() }
            .accessibilityIdentifier("events.details.deepLink")
        } else {
            Text(InAppEventDetail.deepLink.display(viewModel.deepLink(of: event)))
                .textSelection(.enabled)
                .accessibilityIdentifier("events.details.deepLink")
        }
    }

    @ViewBuilder
    private var purposePicker: some View {
        let value = viewModel.detailValue(.purpose, of: event)
        if isEditable {
            Picker("Purpose", selection: Binding { value } set: { viewModel.setDetail(.purpose, to: $0, of: event) }) {
                if value == nil { Text("Not set").tag(String?.none) }
                ForEach(InAppEventPurpose.allCases, id: \.self) { purpose in
                    Text(purpose.title(appName: viewModel.app.name)).tag(String?.some(purpose.rawValue))
                }
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("events.details.purpose")
        } else {
            Text(InAppEventDetail.purpose.display(value, appName: viewModel.app.name))
                .accessibilityIdentifier("events.details.purpose")
        }
    }

    @ViewBuilder
    private var priorityPicker: some View {
        let value = viewModel.detailValue(.priority, of: event)
        if isEditable {
            Picker("Priority", selection: Binding { value } set: { viewModel.setDetail(.priority, to: $0, of: event) }) {
                ForEach(InAppEventPriority.allCases, id: \.self) { priority in
                    Text(priority.title).tag(String?.some(priority.rawValue))
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
            .accessibilityIdentifier("events.details.priority")
        } else {
            Text(InAppEventDetail.priority.display(value))
                .accessibilityIdentifier("events.details.priority")
        }
    }

    @ViewBuilder
    private var languagePicker: some View {
        let value = viewModel.detailValue(.primaryLocale, of: event)
        if isEditable {
            Picker("Primary language", selection: Binding { value } set: { viewModel.setDetail(.primaryLocale, to: $0, of: event) }) {
                if value == nil { Text("Not set").tag(String?.none) }
                ForEach(languageCodes(including: value), id: \.self) { code in
                    Text(InAppEventChangeBuilder.localeName(code)).tag(String?.some(code))
                }
            }
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("events.details.primaryLocale")
        } else {
            Text(InAppEventDetail.primaryLocale.display(value))
                .accessibilityIdentifier("events.details.primaryLocale")
        }
    }

    /// The languages the event has or will have once pushed.
    private func languageCodes(including value: String?) -> [String] {
        var codes = viewModel.languages(of: event).filter { $0.state == .written || $0.state == .notPushed }.map(\.code)
        if let value, !codes.contains(value) { codes.insert(value, at: 0) }
        return codes
    }

    // MARK: - Deep link

    private func syncDeepLink() {
        deepLinkText = viewModel.deepLink(of: event) ?? ""
    }

    /// Return or leaving the field: queued when it's a link App Store
    /// Connect takes, or empty.
    private func commitDeepLink() {
        guard isEditable, viewModel.deepLinkProblem(deepLinkText) == nil else { return }
        let text = deepLinkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != (viewModel.deepLink(of: event) ?? "") else { return }
        viewModel.setDetail(.deepLink, to: text, of: event)
    }

    private func takeFocus() {
        guard let detail = viewModel.focusedDetail else { return }
        viewModel.focusedDetail = nil
        if detail == .deepLink, isEditable { focus = .deepLink }
    }
}

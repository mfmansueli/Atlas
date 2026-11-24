//
//  NominationPage.swift
//  Atlas
//

import SwiftUI

/// A draft's page, one column up to 780 pt (board 70): Type, Name,
/// Description, Dates, Devices, Languages, Countries and regions,
/// Pre-order, Linked In-App Events, Materials, Notes and Apps, with Atlas's
/// and assistants' suggestions where they apply. An assistant's new
/// nomination shows the same page, every field marked as suggested, until
/// it's accepted.
struct NominationPage: View {
    @Bindable var viewModel: NominationsViewModel
    let target: Target
    let actions: NominationsScreen.Actions
    var isCompact = false

    static let maxWidth: CGFloat = 780

    enum Target {
        case nomination(Nomination)
        case proposal(NominationProposal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            NominationsBanner(viewModel: viewModel, nominationID: nomination?.id, actions: actions)
            top
            typeCard
            nameCard
            descriptionCard
            datesCard
            devicesCard
            languagesCard
            countriesCard
            preOrderCard
            eventsCard
            materialsCard
            notesCard
            appsCard
            Text(String(localized: "Nothing is sent until you push. Submitting is a separate step, and asks first.", comment: "kind:description"))
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("nominations.page.footnote")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nominations.page")
    }

    // MARK: - Target

    private var nomination: Nomination? {
        if case let .nomination(nomination) = target { return nomination }
        return nil
    }

    private var proposal: NominationProposal? {
        if case let .proposal(proposal) = target { return proposal }
        return nil
    }

    private var content: NominationContent {
        switch target {
        case let .nomination(nomination): nomination.content
        case let .proposal(proposal): proposal.content
        }
    }

    private var isProposal: Bool { proposal != nil }

    private func change(_ change: (inout NominationContent) -> Void) {
        switch target {
        case let .nomination(nomination): viewModel.update(nomination.id, change)
        case let .proposal(proposal): viewModel.updateProposal(proposal.id, change)
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<NominationContent, Value>) -> Binding<Value> {
        Binding { content[keyPath: keyPath] } set: { value in change { $0[keyPath: keyPath] = value } }
    }

    // MARK: - Top

    @ViewBuilder
    private var top: some View {
        if let proposal {
            NominationAssistantCard(
                title: String(localized: "Nominate \(proposal.content.trimmedName)", comment: "kind:suggestion-title"),
                message: String(localized: "Every field below is suggested. Change anything before you accept.", comment: "kind:suggestion-why"),
                evidence: proposal.evidence,
                receivedAt: proposal.receivedAt,
                acceptTitle: String(localized: "Accept", comment: "kind:button"),
                identifier: "nominations.page.proposal",
                onDismiss: { viewModel.dismissProposal(proposal.id) },
                onAccept: { viewModel.acceptProposal(proposal.id) }
            )
        } else if let nomination {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(viewModel.whereText(nomination))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .accessibilityIdentifier("nominations.page.where")
                if let created = createdText(nomination) {
                    Text(created).font(.subheadline).foregroundStyle(Palette.label2)
                }
                NominationNeedLine(need: viewModel.need(nomination))
            }
            if let change = viewModel.changeProposal(for: nomination.id) {
                let fields = change.content.changedFields(from: nomination.content).map(\.title)
                NominationAssistantCard(
                    title: String(localized: "Suggested changes: \(fields.isEmpty ? String(localized: "none", comment: "kind:other") : fields.joined(separator: ", "))",
                                  comment: "kind:suggestion-title"),
                    evidence: change.evidence,
                    receivedAt: change.receivedAt,
                    acceptTitle: String(localized: "Accept", comment: "kind:button"),
                    identifier: "nominations.page.changes",
                    onDismiss: { viewModel.dismissProposal(change.id) },
                    onAccept: { viewModel.acceptProposal(change.id) }
                )
            }
            if let request = viewModel.actionRequest(for: nomination.id) {
                NominationAssistantCard(
                    title: request.action == .submit
                        ? String(localized: "Submit it to Apple’s editors", comment: "kind:suggestion-title")
                        : String(localized: "Archive it", comment: "kind:suggestion-title"),
                    evidence: request.evidence,
                    receivedAt: request.receivedAt,
                    acceptTitle: request.action == .submit
                        ? String(localized: "Submit…", comment: "kind:button")
                        : String(localized: "Archive…", comment: "kind:button"),
                    identifier: "nominations.page.request",
                    onDismiss: { viewModel.dismissActionRequest(request) },
                    onAccept: { viewModel.acceptActionRequest(request) }
                )
            }
        }
    }

    private func createdText(_ nomination: Nomination) -> String? {
        guard let date = nomination.createdDate?.formatted(.dateTime.month(.abbreviated).day()) else { return nil }
        if let client = nomination.suggestedBy {
            return String(localized: "Suggested \(date) by \(client), accepted", comment: "kind:description")
        }
        guard let person = nomination.createdBy else { return String(localized: "Created \(date)", comment: "kind:description") }
        return String(localized: "Created \(date) by \(person)", comment: "kind:description")
    }

    // MARK: - Fields

    private var typeCard: some View {
        let suggestion = nomination.flatMap { viewModel.builtInSuggestion(.type, for: $0) }
        return NominationFieldCard(
            title: NominationField.type.title,
            subtitle: String(localized: "Required. Tells the editors what kind of story it is.", comment: "kind:description"),
            isSuggested: isProposal,
            identifier: "nominations.field.type"
        ) {
            NominationTypeField(selection: content.type, suggested: suggestion?.type, isCompact: isCompact) { type in
                change { $0.type = type }
            }
            if let suggestion {
                NominationBuiltInCard(
                    suggestion: suggestion,
                    onDismiss: { viewModel.dismissBuiltIn(suggestion) },
                    onAccept: { _ in viewModel.acceptBuiltIn(suggestion) }
                )
            }
        }
    }

    private var nameCard: some View {
        NominationFieldCard(title: NominationField.name.title, isSuggested: isProposal, identifier: "nominations.field.name") {
            NominationTextField(
                placeholder: String(localized: "e.g. Lumen 1.4: Weekly reflections", comment: "kind:placeholder"),
                text: binding(\.name),
                isRequired: true,
                identifier: "nominations.name"
            )
        }
    }

    private var descriptionCard: some View {
        let suggestion = nomination.flatMap { viewModel.builtInSuggestion(.description, for: $0) }
        let refusal = nomination.flatMap { viewModel.refusal(for: $0.id) }
        return NominationFieldCard(
            title: NominationField.description.title, isSuggested: isProposal, identifier: "nominations.field.description"
        ) {
            NominationTextField(
                placeholder: String(localized: "What’s new, who it’s for and why now", comment: "kind:placeholder"),
                text: binding(\.description),
                isRequired: true,
                isMultiline: true,
                isFlagged: refusal != nil,
                identifier: "nominations.description"
            )
            if let nomination, let refusal, refusal.mentionsLink, !NominationLink.links(in: content.description).isEmpty {
                HStack(spacing: Spacing.small) {
                    InlineMessage.warning(
                        String(localized: "Apple refused the link in the description. Materials is the place for links.", comment: "kind:error")
                    )
                    Button("Move Link to Materials") { viewModel.moveLinksToMaterials(nomination.id) }
                        .accessibilityIdentifier("nominations.description.moveLink")
                }
            }
            if let suggestion {
                NominationBuiltInCard(
                    suggestion: suggestion,
                    onDismiss: { viewModel.dismissBuiltIn(suggestion) },
                    onAccept: { useAndEdit in viewModel.acceptBuiltIn(suggestion, useAndEdit: useAndEdit) }
                )
            }
        }
    }

    private var datesCard: some View {
        NominationFieldCard(
            title: NominationField.dates.title,
            subtitle: String(localized: "In each country’s time zone", comment: "kind:description"),
            isSuggested: isProposal,
            identifier: "nominations.field.dates"
        ) {
            NominationDatesField(start: binding(\.publishStart), end: binding(\.publishEnd), type: content.type, now: viewModel.now(), isCompact: isCompact)
        }
    }

    private var devicesCard: some View {
        NominationFieldCard(
            title: NominationField.devices.title,
            subtitle: String(localized: "Where people can use it", comment: "kind:description"),
            isSuggested: isProposal,
            identifier: "nominations.field.devices"
        ) {
            NominationChips(
                options: NominationDevice.allCases.map { NominationChips.Option(id: $0.rawValue, title: $0.title) },
                selected: Set(content.devices.map(\.rawValue)),
                identifier: "nominations.devices"
            ) { raw in
                guard let device = NominationDevice(rawValue: raw) else { return }
                change { content in
                    if content.devices.contains(device) { content.devices.removeAll { $0 == device } } else { content.devices.append(device) }
                }
            }
        }
    }

    private var languagesCard: some View {
        let codes = (viewModel.context.locales + content.locales).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return NominationFieldCard(
            title: NominationField.languages.title,
            trailingNote: String(localized: "\(content.locales.count) of \(codes.count)", comment: "kind:description"),
            isSuggested: isProposal,
            identifier: "nominations.field.languages"
        ) {
            NominationChips(
                options: codes.map { NominationChips.Option(id: $0, title: InAppEventChangeBuilder.localeName($0)) },
                selected: Set(content.locales),
                identifier: "nominations.languages"
            ) { code in
                change { content in
                    if content.locales.contains(code) { content.locales.removeAll { $0 == code } } else { content.locales.append(code) }
                }
            }
        }
    }

    private var countriesCard: some View {
        NominationFieldCard(title: NominationField.countries.title, isSuggested: isProposal, identifier: "nominations.field.countries") {
            NominationCountriesField(territories: binding(\.territories), launchInSelectMarketsFirst: binding(\.launchInSelectMarketsFirst))
        }
    }

    private var preOrderCard: some View {
        NominationFieldCard(title: NominationField.preOrder.title, isSuggested: isProposal, identifier: "nominations.field.preOrder") {
            Toggle(isOn: binding(\.preOrderEnabled)) {
                Text("People can order it before the start date.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
            .toggleStyle(.switch)
            .accessibilityIdentifier("nominations.preOrder")
        }
    }

    private var eventsCard: some View {
        NominationFieldCard(
            title: NominationField.events.title,
            trailingNote: String(localized: "Optional", comment: "kind:description"),
            isSuggested: isProposal,
            identifier: "nominations.field.events"
        ) {
            NominationEventsField(
                linked: content.eventIDs,
                events: viewModel.context.events,
                name: { id in nomination.map { viewModel.eventName(id, in: $0) } ?? viewModel.context.events.first { $0.id == id }?.name ?? id },
                onChange: { ids in change { $0.eventIDs = ids } },
                onOpenEvents: actions.openEvents
            )
        }
    }

    private var materialsCard: some View {
        let known = nomination.map { viewModel.knownLinks(for: $0) } ?? []
        return NominationFieldCard(
            title: NominationField.materials.title,
            trailingNote: String(localized: "Links only", comment: "kind:description"),
            isSuggested: isProposal,
            identifier: "nominations.field.materials"
        ) {
            NominationMaterialsField(links: content.materials, known: known) { links in change { $0.materials = links } }
        }
    }

    private var notesCard: some View {
        NominationFieldCard(title: NominationField.notes.title, isSuggested: isProposal, identifier: "nominations.field.notes") {
            NominationTextField(
                placeholder: String(localized: "Anything the editors should know", comment: "kind:placeholder"),
                text: binding(\.notes),
                isMultiline: true,
                identifier: "nominations.notes"
            )
        }
    }

    private var appsCard: some View {
        let apps = viewModel.context.apps.isEmpty ? [viewModel.app] : viewModel.context.apps
        let count = Set(content.appIDs + [viewModel.app.id]).count
        return NominationFieldCard(
            title: NominationField.apps.title,
            trailingNote: count == 1
                ? String(localized: "\(viewModel.app.name) only", comment: "kind:description")
                : String(localized: "\(count) apps", comment: "kind:description"),
            isSuggested: isProposal,
            identifier: "nominations.field.apps"
        ) {
            NominationAppsField(apps: apps, selected: content.appIDs, openAppID: viewModel.app.id) { ids in change { $0.appIDs = ids } }
        }
    }
}

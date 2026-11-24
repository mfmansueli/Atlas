//
//  NominationReadOnlyPage.swift
//  Atlas
//

import SwiftUI

/// A submitted or archived nomination: what was sent, who sent it and when.
/// Nothing else: Apple doesn't report back, so nothing changes here after
/// it's submitted. The only action is Archive… (in the header).
struct NominationReadOnlyPage: View {
    @Bindable var viewModel: NominationsViewModel
    let nomination: Nomination
    let actions: NominationsScreen.Actions

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            NominationsBanner(viewModel: viewModel, nominationID: nil, actions: actions)
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(headline)
                    .font(.headline)
                    .accessibilityIdentifier("nominations.readOnly.headline")
                ForEach(lines, id: \.self) { line in
                    Text(line).font(.subheadline).foregroundStyle(Palette.label2)
                }
                if let request = viewModel.actionRequest(for: nomination.id), nomination.state == .submitted {
                    NominationAssistantCard(
                        title: String(localized: "Archive it", comment: "kind:suggestion-title"),
                        evidence: request.evidence,
                        receivedAt: request.receivedAt,
                        acceptTitle: String(localized: "Archive…", comment: "kind:button"),
                        identifier: "nominations.page.request",
                        onDismiss: { viewModel.dismissActionRequest(request) },
                        onAccept: { viewModel.acceptActionRequest(request) }
                    )
                    .padding(.top, Spacing.small)
                }
            }
            Card {
                Text("What was sent").font(.headline)
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.large, verticalSpacing: Spacing.small) {
                    ForEach(rows, id: \.0) { row in
                        GridRow {
                            Text(row.0)
                                .font(.subheadline)
                                .foregroundStyle(Palette.label2)
                                .gridColumnAlignment(.leading)
                            Text(row.1)
                                .font(.body)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .accessibilityIdentifier("nominations.readOnly.sent")
            if !nomination.content.eventIDs.isEmpty {
                NominationFieldCard(title: NominationField.events.title, identifier: "nominations.readOnly.events") {
                    NominationEventsField(
                        linked: nomination.content.eventIDs,
                        events: viewModel.context.events,
                        name: { viewModel.eventName($0, in: nomination) },
                        isEditable: false,
                        onChange: { _ in },
                        onOpenEvents: actions.openEvents
                    )
                }
            }
            if !nomination.content.materials.isEmpty {
                NominationFieldCard(title: NominationField.materials.title, identifier: "nominations.readOnly.materials") {
                    NominationMaterialsField(links: nomination.content.materials, known: viewModel.context.links, isEditable: false) { _ in }
                }
            }
            if !nomination.content.trimmedNotes.isEmpty {
                NominationFieldCard(title: NominationField.notes.title, identifier: "nominations.readOnly.notes") {
                    Text(nomination.content.trimmedNotes).textSelection(.enabled)
                }
            }
            Text("Read-only. Apple doesn’t say whether a nomination is chosen.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nominations.readOnly")
    }

    private func date(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .omitted) ?? "—"
    }

    private var headline: String {
        if nomination.state == .archived {
            return String(localized: "Archived on \(date(nomination.lastModifiedDate))", comment: "kind:description")
        }
        let who = nomination.submittedBy.map { String(localized: " by \($0)", comment: "kind:description") } ?? ""
        return String(localized: "Submitted on \(date(nomination.submittedDate))\(who)", comment: "kind:description")
    }

    private var lines: [String] {
        var lines: [String] = []
        if nomination.state == .archived {
            let who = nomination.submittedBy.map { String(localized: " by \($0)", comment: "kind:description") } ?? ""
            lines.append(String(localized: "Submitted on \(date(nomination.submittedDate))\(who)", comment: "kind:description"))
        }
        if let created = nomination.createdDate {
            let who = nomination.createdBy.map { String(localized: " by \($0)", comment: "kind:description") } ?? ""
            lines.append(String(localized: "Created \(date(created))\(who)", comment: "kind:description"))
        }
        lines.append(String(localized: "Apple doesn’t report back on nominations, so nothing changes here after you submit.", comment: "kind:description"))
        return lines
    }

    private var rows: [(String, String)] {
        let content = nomination.content
        let locales = content.locales.map(InAppEventChangeBuilder.localeName).joined(separator: ", ")
        let countries = content.isEverywhere
            ? String(localized: "All \(TerritoryCatalog.standard.count)", comment: "kind:description")
            : content.territories.map { TerritoryCatalog.standard.territory(alpha3: $0)?.name ?? $0 }.joined(separator: ", ")
        let yesText = String(localized: "Yes", comment: "kind:description")
        let noText = String(localized: "No", comment: "kind:description")
        return [
            (NominationField.type.title, content.type?.title ?? "—"),
            (NominationField.name.title, content.trimmedName),
            (NominationField.description.title, content.trimmedDescription),
            (NominationField.dates.title, NominationDayText.dates(content)),
            (NominationField.devices.title, NominationDevice.list(content.devices)),
            (NominationField.languages.title, locales.isEmpty ? "—" : locales),
            (NominationField.countries.title, countries),
            (String(localized: "Launch in some markets first", comment: "kind:field-label"), content.launchInSelectMarketsFirst ? yesText : noText),
            (NominationField.preOrder.title, content.preOrderEnabled ? yesText : noText),
            (NominationField.apps.title, viewModel.appsText(nomination)),
        ]
    }
}

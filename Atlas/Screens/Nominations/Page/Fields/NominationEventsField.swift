//
//  NominationEventsField.swift
//  Atlas
//

import SwiftUI

/// Linked In-App Events: the linked ones, each with Remove, and Link an
/// Event…, a menu of the app's events (ended ones can't be linked) with
/// Open In-App Events.
struct NominationEventsField: View {
    let linked: [String]
    let events: [NominationContext.Event]
    let name: (String) -> String
    var isEditable = true
    let onChange: ([String]) -> Void
    let onOpenEvents: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if linked.isEmpty {
                Text("No events linked. Link one when the nomination is about an event.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
            ForEach(linked, id: \.self) { id in
                HStack(spacing: Spacing.small) {
                    Image(systemName: "calendar")
                        .foregroundStyle(Palette.sectionEvents)
                    VStack(alignment: .leading, spacing: Spacing.tiny) {
                        Text(name(id)).font(.body.weight(.medium))
                        if let detail = events.first(where: { $0.id == id })?.detail, !detail.isEmpty {
                            Text(detail).font(.subheadline).foregroundStyle(Palette.label2)
                        }
                    }
                    Spacer(minLength: Spacing.small)
                    if isEditable {
                        Button("Remove") { onChange(linked.filter { $0 != id }) }
                            .controlSize(.small)
                            .accessibilityIdentifier("nominations.events.remove")
                    } else {
                        Button("Open", action: onOpenEvents)
                            .controlSize(.small)
                    }
                }
                .padding(Spacing.small)
                .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("nominations.events.linked")
            }
            if isEditable {
                Menu("Link an Event…") {
                    if events.isEmpty {
                        Text("\(String(localized: "No In-App Events yet", comment: "kind:empty-state"))")
                    }
                    ForEach(events) { event in
                        Toggle(isOn: Binding { linked.contains(event.id) } set: { isOn in
                            onChange(isOn ? linked + [event.id] : linked.filter { $0 != event.id })
                        }) {
                            Text(event.detail.isEmpty ? event.name : "\(event.name) · \(event.detail)")
                        }
                        .disabled(event.isOver && !linked.contains(event.id))
                    }
                    Divider()
                    Button("Open In-App Events", action: onOpenEvents)
                }
                .menuStyle(.button)
                .fixedSize()
                .accessibilityIdentifier("nominations.events.link")
            }
        }
    }
}

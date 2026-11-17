//
//  NewInAppEventSheet.swift
//  Atlas
//

import SwiftUI

/// New Event: its reference name, badge, purpose, priority, whether it
/// needs a purchase, its deep link and dates. It waits in Review & Push and
/// is created in App Store Connect as a draft when pushed; its texts are
/// written, or suggested, once it's there. An assistant's
/// `propose_in_app_event` queues the same change.
struct NewInAppEventSheet: View {
    let appName: String
    /// Why the event can't be queued as it is (`InAppEventsViewModel.problem(for:)`).
    let problem: (NewInAppEvent) -> String?
    let onCancel: () -> Void
    /// Returns whether the event was queued.
    let onAdd: (NewInAppEvent) -> Bool

    @State private var event: NewInAppEvent
    @State private var showsProblem = false

    init(
        appName: String,
        primaryLocale: String,
        problem: @escaping (NewInAppEvent) -> String?,
        onCancel: @escaping () -> Void,
        onAdd: @escaping (NewInAppEvent) -> Bool
    ) {
        self.appName = appName
        self.problem = problem
        self.onCancel = onCancel
        self.onAdd = onAdd
        var event = NewInAppEvent()
        event.primaryLocale = primaryLocale
        _event = State(initialValue: event)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("New In-App Event")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("For \(appName). It waits in Review & Push; nothing is created in App Store Connect until you push.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(3)
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.top, Spacing.xLarge)
            Form {
                Section {
                    TextField("Reference name", text: $event.referenceName, prompt: Text("Winter Reflection 2026"))
                        .accessibilityIdentifier("events.new.name")
                    Picker("Badge", selection: $event.badge) {
                        ForEach(InAppEventBadge.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Purpose", selection: $event.purpose) {
                        ForEach(InAppEventPurpose.allCases) { Text($0.title(appName: appName)).tag($0) }
                    }
                    Picker("Priority", selection: $event.priority) {
                        ForEach(InAppEventPriority.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Purchase", selection: $event.purchaseRequirement) {
                        ForEach(InAppEventPurchaseRequirement.allCases) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("events.new.purchase")
                    TextField("Deep link", text: $event.deepLink, prompt: Text(verbatim: "https://example.com/event"))
                        .accessibilityIdentifier("events.new.deepLink")
                } footer: {
                    Text("""
                    People never see the reference name. The badge shows on the event’s card, and the deep link opens the event \
                    in the app. Say it needs a purchase only when the event costs extra.
                    """)
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                }
                Section {
                    DatePicker("Starts", selection: $event.eventStart)
                    DatePicker("Ends", selection: $event.eventEnd)
                    DatePicker("Shows on the App Store from", selection: $event.publishStart)
                } footer: {
                    Text("""
                    In every country and region, each in its own time zone. An event lasts up to 31 days, and its card can show \
                    up to 14 days before it starts.
                    """)
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            Divider()
            HStack(spacing: Spacing.small) {
                Text(showsProblem ? currentProblem ?? "" : String(localized: "Add its card and details images in App Store Connect before you submit it."))
                    .font(.caption)
                    .foregroundStyle(showsProblem && currentProblem != nil ? Palette.danger : Palette.label2)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("events.new.note")
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("events.new.cancel")
                Button("Add to Review & Push") {
                    if !onAdd(event) { showsProblem = true }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("events.new.add")
            }
            .buttonBorderShape(.capsule)
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.medium)
        }
        .frame(width: 520, height: 580)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.new.sheet")
    }

    private var currentProblem: String? {
        problem(event)
    }
}

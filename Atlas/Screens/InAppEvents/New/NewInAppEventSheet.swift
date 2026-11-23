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
    /// What App Review's time may do to its dates (`InAppEventsViewModel.warnings(for:)`): never a block.
    let warnings: (NewInAppEvent) -> [String]
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
        onAdd: @escaping (NewInAppEvent) -> Bool,
        warnings: @escaping (NewInAppEvent) -> [String]
    ) {
        self.appName = appName
        self.problem = problem
        self.warnings = warnings
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
                Text("For \(appName). Nothing is created in App Store Connect until you push.")
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
                    TextField("Deep link", text: $event.deepLink, prompt: Text(verbatim: "\(InAppEventDeepLink.slug(appName))://event"))
                        .accessibilityIdentifier("events.new.deepLink")
                } footer: {
                    Text("""
                    People never see the reference name. The badge shows on the card. The deep link opens the event in the \
                    app; add it before you submit. Say it needs a purchase only if it costs extra.
                    """)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                }
                Section {
                    DatePicker("Starts", selection: $event.eventStart)
                    DatePicker("Ends", selection: $event.eventEnd)
                    DatePicker("Card shows from", selection: $event.publishStart)
                } footer: {
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        Text("""
                        Local time in every country or region. Events last up to 31 days; the card can show 14 days before.
                        """)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        // Read again every minute: a date can come within App Review's time while the sheet is open.
                        TimelineView(.everyMinute) { _ in
                            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                                ForEach(warnings(event), id: \.self) { warning in
                                    InlineMessage.warning(warning)
                                        .font(.subheadline)
                                        .accessibilityIdentifier("events.new.warning")
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            Divider()
            HStack(spacing: Spacing.small) {
                Text(showsProblem ? currentProblem ?? "" : footerNote)
                    .font(.subheadline)
                    .foregroundStyle(showsProblem && currentProblem != nil ? Palette.err : Palette.label2)
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

    /// What's still needed before App Review, once it's created: the deep
    /// link when there's none (a draft goes without one), and the art.
    private var footerNote: String {
        event.trimmedDeepLink.isEmpty
            ? String(localized: "No deep link yet. Add it and both images before you submit.")
            : String(localized: "Add its card and details images before you submit it.")
    }
}

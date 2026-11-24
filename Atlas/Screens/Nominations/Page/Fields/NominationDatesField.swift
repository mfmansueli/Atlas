//
//  NominationDatesField.swift
//  Atlas
//

import SwiftUI

/// Dates: the start (required) and the end (optional), in each country's
/// time zone. Under 3 weeks to the start, one amber line (Apple's advice,
/// never a block); a launch gets a grey hint up to about 3 months; only a
/// start that has passed blocks Add and Submit.
struct NominationDatesField: View {
    @Binding var start: Date?
    @Binding var end: Date?
    let type: NominationType?
    let now: Date
    var isCompact = false

    @State private var isPickingStart = false

    /// A launch: Apple suggests nominating up to about 3 months ahead.
    static let launchHintDays = 84

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            let layout = isCompact ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
                : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.xLarge))
            layout {
                startColumn
                endColumn
            }
            notes
        }
    }

    private var startColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("Starts · required")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.label2)
            if let start {
                HStack(spacing: Spacing.small) {
                    DatePicker("Start date", selection: Binding { start } set: { self.start = $0 }, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .accessibilityIdentifier("nominations.dates.start")
                    if let days {
                        Text(NominationDayText.relative(days))
                            .font(.subheadline)
                            .foregroundStyle(days < NominationNeed.closeDays ? Palette.warn : Palette.label2)
                    }
                }
            } else {
                Button("Choose a Date…") {
                    start = Calendar.current.date(byAdding: .day, value: 28, to: Calendar.current.startOfDay(for: now))
                }
                .accessibilityIdentifier("nominations.dates.choose")
            }
        }
    }

    private var endColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text("Ends · optional")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.label2)
            HStack(spacing: Spacing.small) {
                Toggle("Ends", isOn: Binding { end != nil } set: { isOn in
                    end = isOn ? Calendar.current.date(byAdding: .day, value: 14, to: start ?? now) : nil
                })
                .toggleStyle(.checkbox)
                .accessibilityIdentifier("nominations.dates.hasEnd")
                if let end {
                    DatePicker("End date", selection: Binding { end } set: { self.end = $0 }, in: (start ?? now)..., displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .accessibilityIdentifier("nominations.dates.end")
                } else {
                    Text("No end date")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
            }
        }
    }

    @ViewBuilder
    private var notes: some View {
        if let days, days < 0, let start {
            HStack(spacing: Spacing.small) {
                InlineMessage.warning(String(localized: "\(start.formatted(date: .abbreviated, time: .omitted)) has passed. Apple will refuse it.", comment: "kind:error"))
                    .accessibilityIdentifier("nominations.dates.past")
                Button("Pick a New Date…") { isPickingStart = true }
                    .popover(isPresented: $isPickingStart) {
                        DatePicker("Start date", selection: Binding { start } set: { self.start = $0 }, in: now..., displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.graphical)
                            .padding(Spacing.medium)
                    }
                    .accessibilityIdentifier("nominations.dates.pickNew")
            }
        } else if let days, days < NominationNeed.closeDays {
            let launch = type == .appLaunch ? String(localized: ", and up to 3 months for a launch.", comment: "kind:banner")
                : String(localized: ". You can still submit.", comment: "kind:banner")
            InlineMessage.warning(String(localized: "Starts \(NominationDayText.relative(days)). Apple suggests nominating a few weeks ahead\(launch)", comment: "kind:banner"))
                .accessibilityIdentifier("nominations.dates.soon")
        } else if let days, type == .appLaunch, days < Self.launchHintDays {
            Text("For a launch, Apple suggests up to 3 months ahead. You can still submit.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("nominations.dates.launchHint")
        }
    }

    private var days: Int? {
        NominationContent(publishStart: start).daysUntilStart(now: now)
    }
}

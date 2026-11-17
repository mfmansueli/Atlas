//
//  InAppEventList.swift
//  Atlas
//

import SwiftUI

/// The events column: each event, the new ones waiting in Review & Push,
/// and New Event.
struct InAppEventList: View {
    @Bindable var viewModel: InAppEventsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                ForEach(viewModel.events) { event in
                    InAppEventListRow(event: event, status: viewModel.status(of: event), isSelected: event.id == viewModel.selectedEventID) {
                        viewModel.select(event.id)
                    }
                    .accessibilityIdentifier("events.row.\(event.id)")
                }
                ForEach(viewModel.queuedNewEvents) { change in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.title)
                            .font(.callout.weight(.medium))
                            .lineLimit(2)
                        HStack(spacing: Spacing.xSmall) {
                            UnsavedDot(size: 6)
                            Text("Not pushed · \(change.newValue)")
                                .font(.caption)
                                .foregroundStyle(Palette.label2)
                                .lineLimit(2)
                        }
                    }
                    .padding(Spacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("events.queued.\(change.id)")
                }
                Button {
                    viewModel.isNewEventPresented = true
                } label: {
                    Label("New Event", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonBorderShape(.capsule)
                .padding(.top, Spacing.xSmall)
                .padding(.horizontal, 7)
                .accessibilityIdentifier("events.new")
            }
            .padding(.bottom, Spacing.large)
        }
        .scrollIndicators(.never)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.list")
    }
}

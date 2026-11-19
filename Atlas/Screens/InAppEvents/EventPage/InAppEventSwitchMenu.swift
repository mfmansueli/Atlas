//
//  InAppEventSwitchMenu.swift
//  Atlas
//

import SwiftUI

/// The event name's menu (board 40): every event with its card, dates and
/// status, the one shown checked, then All Events back to the gallery.
struct InAppEventSwitchMenu: View {
    @Bindable var viewModel: InAppEventsViewModel
    let currentID: InAppEvent.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(viewModel.events) { event in
                row(event)
            }
            Divider()
                .padding(.vertical, Spacing.xxSmall)
            Button {
                viewModel.showGallery()
            } label: {
                Label("All Events", systemImage: "square.grid.2x2")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .padding(.horizontal, Spacing.small)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("events.menu.all")
        }
        .padding(Spacing.xSmall)
        .frame(width: 320)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Events"))
        .accessibilityIdentifier("events.menu")
    }

    private func row(_ event: InAppEvent) -> some View {
        let isCurrent = event.id == currentID
        let status = viewModel.status(of: event)
        return Button {
            viewModel.open(event.id)
        } label: {
            HStack(spacing: Spacing.small) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.accentText)
                    .opacity(isCurrent ? 1 : 0)
                    .frame(width: 12)
                InAppEventArtwork(event: event, source: viewModel.artSource(.card, of: event), cornerRadius: 5, maxPixel: 200)
                    .frame(width: 53, height: 30)
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.referenceName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(event.datesText)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Pill(text: status.title, style: status.pillStyle)
                    .fixedSize()
            }
            .padding(.horizontal, Spacing.xxSmall)
            .frame(minHeight: 46)
            .background(isCurrent ? Palette.fill1 : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(event.referenceName), \(event.datesText), \(status.title)"))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("events.menu.\(event.id)")
    }
}

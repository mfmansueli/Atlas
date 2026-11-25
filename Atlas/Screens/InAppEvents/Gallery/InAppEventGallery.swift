//
//  InAppEventGallery.swift
//  Atlas
//

import SwiftUI

/// Every event as a tile, at least 270 points wide (board 40), the new
/// events waiting in Review & Push after them, and a line on what an
/// event is. A tile opens the event's page.
struct InAppEventGallery: View {
    @Bindable var viewModel: InAppEventsViewModel

    private let columns = [GridItem(.adaptive(minimum: 270), spacing: 14, alignment: .top)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(viewModel.events) { event in
                        InAppEventGalleryTile(
                            event: event, status: viewModel.status(of: event), card: viewModel.artSource(.card, of: event),
                            texts: viewModel.shownTexts(of: event, locale: event.primaryLocale ?? viewModel.localeCode),
                            readyConcepts: viewModel.readyConcepts(of: event), dates: viewModel.tileDates(of: event),
                            note: viewModel.tileNote(of: event), label: viewModel.tileLabel(of: event)
                        ) {
                            viewModel.open(event.id)
                        }
                    }
                    ForEach(viewModel.queuedNewEvents) { change in
                        InAppEventQueuedTile(change: change)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Events"))
                .accessibilityIdentifier("events.gallery")
                Text("Each event is a card in search, Today and on \(viewModel.app.name)’s page. Open one to write it, add artwork and send it to App Review.")
                    .font(.footnote)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("events.gallery.footer")
            }
            .padding(.bottom, Spacing.large)
        }
        .leavesChatRoom()
        .scrollIndicators(.automatic)
    }
}

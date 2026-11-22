//
//  InAppEventsScreen.swift
//  Atlas
//

import SwiftUI

/// In-App Events (board 40): the gallery of every event, or one event's
/// page in its place, with its header (‹ Events, the name as a menu of the
/// others, its status and its one action).
struct InAppEventsScreen: View {
    @Bindable var viewModel: InAppEventsViewModel
    let artworkActions: EventArtworkPanelActions
    let onFooterAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.showsEvent, let event = viewModel.selectedEvent, viewModel.state.value != nil {
                InAppEventPageHeader(viewModel: viewModel, event: event, onAction: onFooterAction)
                InAppEventPage(viewModel: viewModel, event: event, flow: flowFor(event), actions: artworkActions)
            } else {
                galleryHeader
                content
            }
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.content)
    }

    private func flowFor(_ event: InAppEvent) -> EventArtworkFlow? {
        viewModel.artworkFlow?.event.id == event.id ? viewModel.artworkFlow : nil
    }

    private var galleryHeader: some View {
        SectionHeader(
            subtitle: String(localized: "Cards on the App Store for what’s happening in \(viewModel.app.name), in every language.")
        ) {
            // Writing and artwork are the toolbar's Autopilot (board 57).
            if viewModel.state.value != nil {
                Button {
                    viewModel.isNewEventPresented = true
                } label: {
                    Label("New Event…", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("events.new")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            HStack(alignment: .top, spacing: 14) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBlock(height: 230, cornerRadius: 18)
                }
            }
            .accessibilityIdentifier("events.loading")
        case let .failed(message):
            Banner(kind: .apiError, title: String(localized: "Couldn’t read the In-App Events"), message: message, isInline: true) {
                Button("Try Again") {
                    Task { await viewModel.load(force: true) }
                }
            }
            .accessibilityIdentifier("events.error.load")
            Spacer(minLength: 0)
        case .loaded:
            if viewModel.events.isEmpty, viewModel.queuedNewEvents.isEmpty {
                ContentUnavailableView {
                    Label("No In-App Events", systemImage: AppWorkspaceSection.inAppEvents.systemImage)
                } description: {
                    Text("An event is a card on the App Store for something happening in \(viewModel.app.name): a challenge, a new season, a major update.")
                } actions: {
                    Button("New Event…") { viewModel.isNewEventPresented = true }
                        .accessibilityIdentifier("events.empty.new")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("events.empty")
            } else {
                InAppEventGallery(viewModel: viewModel)
            }
        }
    }
}

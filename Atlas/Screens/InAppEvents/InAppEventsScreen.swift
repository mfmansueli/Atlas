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
            // The general request (board 40's `ask-ev`) goes to the
            // toolbar like the Autopilot menu's (boards 56 and 57).
            if viewModel.state.value != nil {
                // Nothing to write texts for yet: the toolbar's Suggest an
                // Event… is the assistant's (board 74 · 3).
                // New Event… is the toolbar's page action (board 80).
                if !viewModel.showsEmptyState {
                    InAppEventsAskButton(app: viewModel.app)
                        .buttonBorderShape(.capsule)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            HStack(alignment: .top, spacing: Spacing.medium) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonBlock(height: Metrics.skeletonEventCardHeight, cornerRadius: Radius.popover)
                }
            }
            .loadingSkeleton(LoadingCopy.events, identifier: "events.loading")
        case let .failed(message):
            Banner(kind: .apiError, title: String(localized: "Couldn’t read the In-App Events"), message: message, isInline: true) {
                Button("Try Again") {
                    Task { await viewModel.load(force: true) }
                }
            }
            .accessibilityIdentifier("events.error.load")
            Spacer(minLength: 0)
        case .loaded:
            if viewModel.showsEmptyState {
                InAppEventsEmptyState(appName: viewModel.app.name)
            } else {
                InAppEventGallery(viewModel: viewModel)
            }
        }
    }
}

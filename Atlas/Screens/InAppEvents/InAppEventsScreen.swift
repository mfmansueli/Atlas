//
//  InAppEventsScreen.swift
//  Atlas
//

import SwiftUI

/// In-App Events: the events on the left, the selected event's texts in
/// every language in the middle, and its card as people see it on the App
/// Store on the right.
struct InAppEventsScreen: View {
    @Bindable var viewModel: InAppEventsViewModel
    let onFooterAction: () -> Void

    @State private var width: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                systemImage: AppWorkspaceSection.inAppEvents.systemImage,
                tint: Palette.sectionEvents,
                title: String(localized: "In-App Events"),
                subtitle: String(localized: "Cards on the App Store for what’s happening in \(viewModel.app.name), in every language.")
            ) {
                if viewModel.state.value != nil {
                    InAppEventsAskButton(app: viewModel.app)
                        .buttonBorderShape(.capsule)
                }
            }
            content
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.content)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            HStack(alignment: .top, spacing: Spacing.large) {
                SkeletonBlock(height: 240, cornerRadius: Radius.card)
                    .frame(width: listWidth)
                SkeletonBlock(height: 320, cornerRadius: Radius.card)
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
                columns
            }
        }
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: Spacing.large) {
            InAppEventList(viewModel: viewModel)
                .frame(width: listWidth)
            if let event = viewModel.selectedEvent {
                InAppEventEditor(viewModel: viewModel, event: event, onFooterAction: onFooterAction)
                    .frame(maxWidth: .infinity)
                if width >= 800 {
                    preview(event)
                        .frame(width: 270)
                }
            } else {
                Text("Push the new event in Review & Push; then its languages are written here.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var listWidth: CGFloat { width < 700 ? 170 : 220 }

    /// The card with the suggestion while one waits, else with what's
    /// written (or what people see instead: the primary language).
    private func preview(_ event: InAppEvent) -> some View {
        let suggestion = viewModel.suggestion
        let language = viewModel.selectedLanguage
        let languageName = language?.name ?? viewModel.localeCode
        let name = suggestion?.name ?? Self.shown(viewModel.text(.name), else: viewModel.fallbackText(.name))
        let short = suggestion?.shortDescription ?? Self.shown(viewModel.text(.shortDescription), else: viewModel.fallbackText(.shortDescription))
        let primary = event.primaryLocale.map(InAppEventChangeBuilder.localeName) ?? ""
        return InAppEventPreview(
            app: viewModel.app, event: event, name: name, shortDescription: short,
            isRightToLeft: language?.isRightToLeft ?? false,
            note: suggestion == nil
                ? String(localized: "Showing \(languageName)")
                : String(localized: "Showing the suggestion. Until you accept it, people who read \(languageName) see \(primary)."),
            showsSuggestion: suggestion != nil,
            now: viewModel.now()
        )
    }

    private static func shown(_ text: String, else fallback: String) -> String {
        text.isEmpty ? fallback : text
    }
}

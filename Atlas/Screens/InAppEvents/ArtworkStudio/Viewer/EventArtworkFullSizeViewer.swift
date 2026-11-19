//
//  EventArtworkFullSizeViewer.swift
//  Atlas
//

import AppKit
import SwiftUI

/// An event's artwork full size, over the whole window (board 47): black
/// in light and dark, the concept's card or details image as large as it
/// fits with the App Store's text over it in a language of its own, the
/// film of concepts, Ask for Changes… in a floating panel, Use This
/// Artwork, and full screen with a pill of its own. ← → go round the
/// concepts, esc leaves full screen and then closes, ⌃⌘F is full screen.
struct EventArtworkFullSizeViewer: View {
    @Bindable var flow: EventArtworkFlow
    @Bindable var viewModel: InAppEventsViewModel

    @State private var loopPlayer = AppPreviewPlayerModel()
    @State private var window: NSWindow?
    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let isNarrow = proxy.size.width < 900
            ZStack {
                EventArtworkViewerStyle.background
                if let viewer = flow.viewer {
                    content(viewer, isNarrow: isNarrow)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.escape) {
            escape()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            flow.stepViewer(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            flow.stepViewer(1)
            return .handled
        }
        .onKeyPress(characters: ["f"]) { press in
            guard press.modifiers.contains(.control), press.modifiers.contains(.command) else { return .ignored }
            toggleFull()
            return .handled
        }
        .onAppear { isFocused = true }
        .onDisappear { loopPlayer.pause() }
        .onChange(of: flow.viewer?.conceptID) { loopPlayer.pause() }
        .onChange(of: flow.viewer?.kind) { loopPlayer.pause() }
        .background(MainWindowAccessor { found in
            guard found !== window else { return }
            Task { @MainActor in window = found }
        })
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { note in
            // Left full screen another way (the green button, the menu).
            guard (note.object as? NSWindow) === window, flow.viewer?.enteredFullScreen == true else { return }
            flow.viewer?.isFull = false
            flow.viewer?.enteredFullScreen = false
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Artwork, full size"))
        .accessibilityIdentifier("events.art.viewer")
    }

    @ViewBuilder
    private func content(_ viewer: EventArtworkViewer, isNarrow: Bool) -> some View {
        let event = flow.event
        VStack(spacing: 0) {
            if !viewer.isFull {
                EventArtworkViewerTopBar(flow: flow, viewer: viewer, isNarrow: isNarrow, onClose: close, onFullScreen: toggleFull)
            }
            EventArtworkViewerStage(
                flow: flow, viewer: viewer, event: event, texts: viewModel.overlayTexts(viewer.kind, of: event, locale: viewer.locale),
                ownSource: viewModel.artSource(viewer.kind, of: event, locale: viewer.locale), loopPlayer: loopPlayer
            )
            if !viewer.isFull {
                EventArtworkViewerBottomBar(
                    flow: flow, viewer: viewer, locales: flow.viewerLocales(pageLocale: viewModel.localeCode, languages: viewModel.languages(of: event).map(\.code)),
                    isNarrow: isNarrow, onUse: use
                )
            }
        }
        if viewer.isAsking, !viewer.isFull, let concept = flow.viewerConcept {
            EventArtworkViewerAskPanel(flow: flow, name: concept.name)
                .padding(.trailing, Spacing.large)
                .padding(.bottom, 74)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        if viewer.isFull {
            EventArtworkViewerHUD(flow: flow, onUse: use, onExit: toggleFull)
                .padding(.top, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        if let toast = viewModel.toast {
            ActionToast(message: toast) {
                viewModel.undoAccept()
            } onAction: {
                viewModel.toast = nil
            } onDismiss: {
                if viewModel.toast == toast { viewModel.toast = nil }
            }
            .padding(.bottom, viewer.isFull ? Spacing.xLarge : 96)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    // MARK: - Actions

    private func use() {
        let id = flow.viewer?.conceptID
        Task {
            await leaveFullScreen()
            await flow.use(id)
        }
    }

    /// Esc: the Ask panel first, then full screen, then the viewer.
    private func escape() {
        if flow.viewer?.isAsking == true {
            flow.closeAsk()
        } else if flow.viewer?.isFull == true {
            toggleFull()
        } else {
            close()
        }
    }

    private func close() {
        Task {
            await leaveFullScreen()
            flow.closeViewer()
        }
    }

    private func toggleFull() {
        guard var viewer = flow.viewer else { return }
        if viewer.isFull {
            Task { await leaveFullScreen() }
            return
        }
        viewer.isFull = true
        viewer.isAsking = false
        if let window, !window.styleMask.contains(.fullScreen) {
            viewer.enteredFullScreen = true
            window.toggleFullScreen(nil)
        }
        flow.viewer = viewer
    }

    /// Back from full screen, the window too when the viewer took it there.
    private func leaveFullScreen() async {
        guard let viewer = flow.viewer, viewer.isFull else { return }
        flow.viewer?.isFull = false
        flow.viewer?.enteredFullScreen = false
        if viewer.enteredFullScreen, let window, window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
            try? await Task.sleep(for: .milliseconds(700))
        }
    }
}

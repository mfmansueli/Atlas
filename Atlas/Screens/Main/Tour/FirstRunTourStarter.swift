//
//  FirstRunTourStarter.swift
//  Atlas
//

import SwiftUI

/// The main window's side of the tour: starts it on Overview the first
/// time this Mac shows an app (or on a DEBUG scene's tip), shows the
/// sidebar while a tip shows, since three of them point into it, and puts
/// the tour in the environment for the tips' anchors.
struct FirstRunTourStarter: ViewModifier {
    let tour: FirstRunTour
    /// The library shows an app, with its toolbar: the tips have their places.
    let isReady: Bool
    /// The tour starts by itself the first time this Mac shows an app.
    let startsOnFirstRun: Bool
    let navigator: WorkspaceNavigator
    @Binding var columnVisibility: NavigationSplitViewVisibility

    func body(content: Content) -> some View {
        content
            .task(id: isReady) { await startIfDue() }
            .task(id: navigator.requestsTour) { await startRequested() }
            .onChange(of: tour.step) {
                if tour.isShowing, columnVisibility == .detailOnly { columnVisibility = .all }
            }
            .environment(tour)
    }

    /// A DEBUG scene's tip, or its first run.
    private var opening: TourStep? {
        #if DEBUG
        NavigationDebugLaunch.tourStep
        #else
        nil
        #endif
    }

    private var startsByItself: Bool {
        #if DEBUG
        startsOnFirstRun || NavigationDebugLaunch.startsTourOnFirstRun
        #else
        startsOnFirstRun
        #endif
    }

    /// Show the Tour: the tips start again from the first, on Overview,
    /// once an app shows. After the click that asked, so the first tip
    /// isn't closed as if by a click elsewhere.
    private func startRequested() async {
        guard navigator.requestsTour else { return }
        navigator.requestsTour = false
        guard isReady else { return }
        navigator.section = .overview
        if columnVisibility == .detailOnly { columnVisibility = .all }
        try? await Task.sleep(for: .milliseconds(150))
        tour.start()
    }

    private func startIfDue() async {
        guard isReady, let step = tour.dueStep(opening: opening, startsOnFirstRun: startsByItself) else { return }
        // Once the window and its toolbar are on screen: a popover asked
        // for before then doesn't show.
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled, isReady, !tour.isShowing else { return }
        navigator.section = .overview
        tour.start(at: step)
    }
}

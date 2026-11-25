//
//  ReviewPushPill.swift
//  Atlas
//

import SwiftUI

/// Review & Push at the bottom of the window (board 80), to the right of
/// the Autopilot bar and aligned to its foot: what you ask for and what
/// you send in one place. It counts the changes, screenshots and extras
/// waiting across all apps; while a push runs it says how many were sent,
/// so the sheet can be minimized and a click opens the progress again
/// (⇧⌘P, Workspace menu). It's the only way to push: no page has a push
/// button of its own.
///
/// What the person accepts flies here as a chip (`PushFlightCenter`):
/// the count holds what's still in the air and goes up as each lands, and
/// the pill pulses. Self-contained: it reads the queue, the push and the
/// navigator from the environment, so the bottom bar only places it.
struct ReviewPushPill: View {
    /// Icon and count only; nil folds it in a window under 700 pt.
    var isCompact: Bool?

    @Environment(ChangeQueue.self) private var changes
    @Environment(PushController.self) private var push
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The count shown, less what's still flying here; nil until the
    /// queue first changes.
    @State private var shownCount: Int?
    @State private var windowWidth: CGFloat = 0

    private var flights: PushFlightCenter { .shared }

    var body: some View {
        let snapshot = snapshot
        ReviewPushPillFace(
            state: ReviewPushPillState(count: shownCount ?? snapshot.count, sending: push.sendingProgress),
            isCompact: isCompact ?? ReviewPushPillState.isCompact(windowWidth: windowWidth),
            landings: flights.landings
        ) {
            navigator.isReviewPresented = true
        }
        .background {
            PushFlightTargetView(anchor: flights.anchor) { windowWidth = $0 }
        }
        .tourTip(.reviewPush, arrowEdge: .top)
        .onAppear { flights.startWatchingClicks() }
        .onChange(of: snapshot) { old, new in
            // Nothing flies to a pill hidden by its own sheet.
            if !navigator.isReviewPresented {
                flights.queueChanged(from: old, to: new, reduceMotion: reduceMotion)
            }
            shownCount = max(0, new.count - flights.unitsInAir)
        }
        .onChange(of: flights.landings) {
            let count = max(0, snapshot.count - flights.unitsInAir)
            withAnimation(reduceMotion ? nil : MotionTiming.tick.animation) { shownCount = count }
        }
    }

    /// What waits in Review & Push now.
    private var snapshot: PushQueueSnapshot {
        PushQueueSnapshot(
            changes: changes.changes,
            imageCount: push.screenshots.imageCount,
            extras: push.screenshots.extras.orderedPlans.flatMap(\.items)
        )
    }
}

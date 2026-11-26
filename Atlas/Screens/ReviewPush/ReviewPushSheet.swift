//
//  ReviewPushSheet.swift
//  Atlas
//

import SwiftUI

/// Review & Push (⇧⌘P, 800 pt), in two tabs (README-DS §15, board 90). To
/// Push: every pending change grouped by app and section, each as old →
/// new with its source, a checkbox and a discard button; a click on an
/// image opens it large over the sheet. Activity (⌘Y): every push from
/// this Mac (`ActivityList`); restoring puts the old values on To Push and
/// never pushes. It opens on Activity when nothing waits. Once a push
/// starts, the same sheet shows its progress (`PushProgressSheet`): the
/// changes, screenshots and extras as one push, ending with Show in
/// Activity.
struct ReviewPushSheet: View {
    @State private var viewModel: ReviewPushViewModel
    @State private var pushToConfirm: [PendingChange]?
    /// Images waiting on that confirmation: all of them, or the checked.
    @State private var imagesToConfirm: Bool?
    @State private var isConfirmingDiscard = false
    /// Restore Previous Screenshots… for one push.
    @State private var restoringScreenshots: ScreenshotRestorePresentation?
    /// "The previous values for 23 changes are in Review & Push. Nothing
    /// was pushed."
    @State private var toast: ToastMessage?

    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(AppPreferences.self) private var preferences
    @Environment(PushHistory.self) private var history
    @Environment(\.dismiss) private var dismiss

    init(viewModel: ReviewPushViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Disabled under the viewer, so Esc and Return reach it rather
            // than Cancel and Push, or Minimize and Done.
            Group {
                if PushProgressSummary.isShowing(viewModel.push) {
                    PushProgressSheet(
                        viewModel: viewModel, onViewResults: viewResults, onShowInActivity: showInActivity, onDone: finish, onMinimize: { dismiss() }
                    )
                } else {
                    tabs
                }
            }
            .disabled(viewModel.viewer != nil)
            .accessibilityHidden(viewModel.viewer != nil)
            if let viewer = viewModel.viewer {
                ReviewFullSizeViewer(viewModel: viewModel, viewer: viewer)
            }
        }
        // Screenshots need the room for old → new side by side.
        .frame(width: showsImages ? 860 : 800, height: showsImages ? 690 : 660)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review.sheet")
        .confirmationDialog(
            "Push \(pushToConfirm?.count ?? 0) changes?",
            isPresented: Binding(get: { pushToConfirm != nil }, set: { if !$0 { pushToConfirm = nil } }),
            presenting: pushToConfirm
        ) { changes in
            Button("Push") {
                if let selectedOnly = imagesToConfirm { viewModel.startImagePush(selectedOnly: selectedOnly) }
                viewModel.startPush(changes)
            }
            .accessibilityIdentifier("review.confirmPush")
            Button("Cancel", role: .cancel) {}
        } message: { changes in
            Text(viewModel.confirmationMessage(for: changes) ?? "")
        }
        .confirmationDialog(
            "Discard \(viewModel.visibleChanges.count) changes?",
            isPresented: $isConfirmingDiscard
        ) {
            Button("Discard All", role: .destructive) { viewModel.discardVisible() }
                .accessibilityIdentifier("review.confirmDiscard")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They're removed from this Mac. Nothing in App Store Connect changes.")
        }
    }

    private var showsImages: Bool {
        viewModel.screenshots.run != nil || viewModel.extras.run != nil || viewModel.showsScreenshots
    }

    // MARK: - Tabs

    /// To Push · Activity, a segmented control over the tab.
    private var tabs: some View {
        @Bindable var navigator = navigator
        return VStack(spacing: 0) {
            Picker(String(localized: "Review & Push", comment: "kind:accessibility-label · the To Push and Activity tabs"), selection: $navigator.reviewTab) {
                ForEach(ReviewPushTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.top, Spacing.large)
            .accessibilityIdentifier("review.tabs")
            switch navigator.reviewTab {
            case .toPush: review
            case .activity: activity
            }
        }
        // Screenshot plans read on either tab, so To Push has them.
        .modifier(ScreenshotReviewLoader(viewModel: viewModel))
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReviewHeader(viewModel: viewModel)
            Divider()
            changeList
                .overlay(alignment: .bottom) { toastView }
            Divider()
            if viewModel.visibleImages.isEmpty {
                ReviewFooter(
                    viewModel: viewModel,
                    onDiscardAll: discardAll,
                    onCancel: { dismiss() },
                    onPush: push
                )
            } else {
                ScreenshotReviewFooter(
                    viewModel: viewModel,
                    onDiscardAll: discardAll,
                    onCancel: { dismiss() },
                    onPushSelected: { push(viewModel.selectedPushableChanges, imagesSelectedOnly: true) },
                    onPushAll: { push(viewModel.pushableChanges, imagesSelectedOnly: false) }
                )
            }
        }
    }

    private var changeList: some View {
        Group {
            if viewModel.visibleChanges.isEmpty, !ScreenshotReviewContent.hasContent(viewModel) {
                // Board 74 · 10: the smaller empty state, in a sheet; Push
                // stays off.
                EmptyStateView(
                    String(localized: "Nothing to push", comment: "kind:empty-state"),
                    systemImage: "checkmark.circle",
                    text: String(
                        localized: "Accepted suggestions and edited fields wait here until you push them to App Store Connect.",
                        comment: "kind:description"
                    ),
                    size: .inline
                )
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityIdentifier("review.empty")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.medium) {
                        ForEach(viewModel.appGroups) { app in
                            Text(app.appName)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Palette.label2)
                                .padding(.top, Spacing.xSmall)
                            ForEach(app.groups) { group in
                                ReviewChangeGroupView(
                                    group: group,
                                    viewModel: viewModel,
                                    onEditSchedule: editScheduleAction(for: group)
                                )
                            }
                        }
                        ScreenshotReviewContent(viewModel: viewModel, onShowInCaptions: showInCaptions)
                    }
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.medium)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// The toast after Restore Previous Values, over the list's foot.
    @ViewBuilder
    private var toastView: some View {
        if let toast {
            ActionToast(message: toast) {
                if self.toast?.id == toast.id { self.toast = nil }
            }
            .padding(.horizontal, Spacing.large)
            .padding(.bottom, Spacing.medium)
        }
    }

    // MARK: - Activity

    private var activity: some View {
        VStack(alignment: .leading, spacing: 0) {
            ActivityList(
                records: history.records,
                highlightedID: navigator.highlightedPushID,
                onResults: showResults,
                onRestore: restore,
                onRestoreScreenshots: viewModel.push.screenshots.canPush
                    ? { restoringScreenshots = ScreenshotRestorePresentation(recordID: $0.id) }
                    : nil
            )
            .frame(maxHeight: .infinity)
            Divider()
            HStack {
                Spacer()
                Button(String(localized: "Done", comment: "kind:button · closes Review & Push from Activity")) { dismiss() }
                    .primaryButton(isDefault: true)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("activity.done")
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.medium)
        }
        .sheet(item: $restoringScreenshots) { presentation in
            if let record = history.records.first(where: { $0.id == presentation.recordID }) {
                ScreenshotRestoreSheet(record: record, locale: presentation.locale) {
                    restoringScreenshots = nil
                    showRestored(record)
                }
            }
        }
        .task(id: viewModel.push.screenshots.workspace?.teamName) {
            if let pending = viewModel.push.screenshots.pendingRestore {
                viewModel.push.screenshots.pendingRestore = nil
                restoringScreenshots = pending
            }
        }
    }

    /// Restore Previous Values: the old values on To Push, and the toast
    /// that says nothing was pushed.
    private func restore(_ record: PushRecord) {
        guard let message = ActivityRestore.restore(record, into: viewModel.queue) else { return }
        showRestored(record)
        toast = message
    }

    /// To Push, on every app's changes when the push was another app's.
    private func showRestored(_ record: PushRecord) {
        if record.appID != viewModel.selectedAppID { viewModel.scope = .allApps }
        navigator.showToPush()
    }

    private func showResults() {
        dismiss()
        navigator.open(.subscriptionPricing, intent: .showResults)
    }

    /// Show in Activity, at the end of a push: Activity, on the push that
    /// just ended.
    private func showInActivity() {
        let pushID = history.records.first?.id
        dismissFinishedPushes()
        navigator.openActivity(highlighting: pushID)
    }

    private func push(_ changes: [PendingChange]) {
        guard !changes.isEmpty else { return }
        if viewModel.confirmationMessage(for: changes) != nil {
            imagesToConfirm = nil
            pushToConfirm = changes
        } else {
            viewModel.startPush(changes)
        }
    }

    /// Pushes text changes and images together; the images wait for a
    /// confirmation the changes need.
    private func push(_ changes: [PendingChange], imagesSelectedOnly: Bool) {
        guard !changes.isEmpty, viewModel.confirmationMessage(for: changes) != nil else {
            viewModel.startImagePush(selectedOnly: imagesSelectedOnly)
            if !changes.isEmpty { viewModel.startPush(changes) }
            return
        }
        imagesToConfirm = imagesSelectedOnly
        pushToConfirm = changes
    }

    /// Opens Captions on the first failing render.
    private func showInCaptions(_ exclusion: ScreenshotPlanExclusion) {
        viewModel.screenshots.showInCaptions(exclusion)
        dismiss()
        navigator.open(.screenshots, intent: .showScreenshots, appID: exclusion.appID)
    }

    private func discardAll() {
        viewModel.discardVisibleImages()
        if !viewModel.visibleExtras.isEmpty {
            Task { await viewModel.discardVisibleExtras() }
        }
        guard !viewModel.visibleChanges.isEmpty else { return }
        if preferences.confirmsDiscarding {
            isConfirmingDiscard = true
        } else {
            viewModel.discardVisible()
        }
    }

    private func editScheduleAction(for group: ReviewChangeGroup) -> (() -> Void)? {
        guard group.section == .subscriptionPricing, let productID = group.groupID else { return nil }
        return {
            dismiss()
            navigator.open(.subscriptionPricing, intent: .editPriceSchedule(productID: productID))
        }
    }

    private func viewResults() {
        dismissFinishedPushes()
        dismiss()
        navigator.open(.subscriptionPricing, intent: .showResults)
    }

    private func finish() {
        dismissFinishedPushes()
        dismiss()
    }

    /// Clears the finished pushes, so the sheet shows the list next time.
    private func dismissFinishedPushes() {
        viewModel.closeViewer()
        viewModel.push.dismissFinished()
        viewModel.screenshots.dismissFinished()
        viewModel.extras.dismissFinished()
    }
}

//
//  NewVersionSheet.swift
//  Atlas
//

import SwiftUI

/// "New Version": the number (the latest plus one to start with) and, for
/// an app on several platforms, which one. Add to Review & Push queues it;
/// App Store Connect creates it when the person pushes.
struct NewVersionSheet: View {
    let viewModel: StorePageViewModel

    @State private var draft: NewAppVersion
    @Environment(\.dismiss) private var dismiss

    init(viewModel: StorePageViewModel) {
        self.viewModel = viewModel
        _draft = State(initialValue: viewModel.newVersionStart)
    }

    private var problem: NewAppVersionProblem? { viewModel.newVersionProblem(draft) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text("New Version")
                    .font(.title2.weight(.semibold))
                Text("App Store Connect creates it when you push, in Prepare for Submission. Then you edit its What’s New and other texts here.")
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding([.horizontal, .top], Spacing.xLarge)
            .padding(.bottom, Spacing.medium)
            form
                .padding(.horizontal, Spacing.xLarge)
                .padding(.bottom, Spacing.large)
            Divider()
            HStack(spacing: Spacing.small) {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("storePage.newVersion.cancel")
                Spacer()
                Button("Add to Review & Push") {
                    viewModel.queueNewVersion(draft)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(problem != nil)
                .accessibilityIdentifier("storePage.newVersion.add")
            }
            .buttonBorderShape(.capsule)
            .padding(Spacing.large)
        }
        .frame(width: 480)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("storePage.newVersion")
    }

    private var form: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.medium, verticalSpacing: Spacing.small) {
            if viewModel.newVersionPlatforms.count > 1 {
                GridRow {
                    Text("Platform")
                        .gridColumnAlignment(.trailing)
                    Picker("Platform", selection: platform) {
                        ForEach(viewModel.newVersionPlatforms, id: \.self) { platform in
                            Text(StorePageVersion.title(ofPlatform: platform) ?? platform).tag(platform)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .accessibilityIdentifier("storePage.newVersion.platform")
                }
            }
            GridRow {
                Text("Version")
                    .gridColumnAlignment(.trailing)
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    TextField("1.0", text: $draft.versionString)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .accessibilityLabel(Text("Version number"))
                        .accessibilityIdentifier("storePage.newVersion.number")
                    note
                }
            }
        }
    }

    @ViewBuilder
    private var note: some View {
        if let problem {
            InlineMessage.warning(problem.message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("storePage.newVersion.problem")
        } else if let latest = viewModel.latestVersion(on: draft.platform) {
            Text("The latest is \(latest.versionString), \(latest.state.title).")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .accessibilityIdentifier("storePage.newVersion.latest")
        }
    }

    /// Picking another platform starts its number from its own latest.
    private var platform: Binding<String> {
        Binding {
            draft.platform
        } set: { platform in
            guard platform != draft.platform else { return }
            draft = NewAppVersion(versionString: viewModel.suggestedNewVersionNumber(on: platform), platform: platform)
        }
    }
}

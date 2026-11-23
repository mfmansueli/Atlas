//
//  AddAppSheet.swift
//  Atlas
//

import SwiftUI

/// Add App (Redesign, 23 November), from the app menu's Add App…: the
/// team's apps that the menu doesn't show yet, read from App Store
/// Connect when it opens, each with Add, which puts it in the menu and
/// opens it. Another team's apps are behind Switch Account or Key….
struct AddAppSheet: View {
    let viewModel: AppListViewModel
    /// The open team's name; nil says “this team”.
    let teamName: String?
    let onAdded: (StoreApp) -> Void
    let onSwitchAccount: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var apps: [StoreApp]?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(String(localized: "Add App", comment: "kind:sheet-title"))
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(AccountsSheetText.addAppSubtitle(team: teamName))
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.top, Spacing.xLarge)
            .padding(.bottom, Spacing.medium)
            content
                .padding(.horizontal, Spacing.xLarge)
                .padding(.bottom, Spacing.medium)
            Divider()
            HStack(spacing: Spacing.xxSmall) {
                Text(String(localized: "Another team’s apps:", comment: "kind:hint"))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                Button(String(localized: "Switch Account or Key…", comment: "kind:button")) {
                    dismiss()
                    onSwitchAccount()
                }
                .plainButton()
                .font(.subheadline)
                .accessibilityIdentifier("addApp.switchAccount")
                Spacer(minLength: Spacing.small)
                Button(String(localized: "Done", comment: "kind:button")) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("addApp.done")
            }
            .buttonBorderShape(.capsule)
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.medium)
        }
        .frame(width: 480)
        .task { await read() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("addApp.sheet")
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            HStack(spacing: Spacing.small) {
                InlineMessage.error(errorMessage)
                Button(String(localized: "Try Again", comment: "kind:button")) {
                    Task { await read() }
                }
            }
            .accessibilityIdentifier("addApp.error")
        } else if let apps {
            if apps.isEmpty {
                Text(AccountsSheetText.addAppEmpty(team: teamName))
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .padding(.vertical, Spacing.small)
                    .accessibilityIdentifier("addApp.empty")
            } else {
                VStack(spacing: 0) {
                    ForEach(apps) { app in
                        Divider()
                        row(app)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.small) {
                ForEach(0..<2, id: \.self) { _ in
                    SkeletonBlock(height: 30, cornerRadius: Radius.menuRow)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(String(localized: "Reading the team’s apps", comment: "kind:loading")))
            .accessibilityIdentifier("addApp.loading")
        }
    }

    private func row(_ app: StoreApp) -> some View {
        HStack(spacing: 10) {
            AppIconTile(name: app.name, icon: app.icon, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(app.bundleID)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(String(localized: "Add", comment: "kind:button")) {
                viewModel.add(app)
                dismiss()
                onAdded(app)
            }
            .rowActionButton()
            .accessibilityIdentifier("addApp.add.\(app.id)")
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
    }

    private func read() async {
        errorMessage = nil
        do {
            apps = try await viewModel.appsNotShown()
        } catch {
            apps = nil
            errorMessage = error.localizedDescription
        }
    }
}

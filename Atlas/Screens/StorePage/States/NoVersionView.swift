//
//  NoVersionView.swift
//  Atlas
//

import SwiftUI

/// "No version to edit": only the live version exists, so version texts
/// can't change until a new version is created: Create Version 1.4… queues
/// it in Review & Push, or it's made in App Store Connect. The app-level
/// fields stay editable, through "View Version 1.3".
struct NoVersionView: View {
    let viewModel: StorePageViewModel

    var body: some View {
        let live = viewModel.content?.version.versionString ?? ""
        let queued = viewModel.queuedNewVersions.first
        let next = viewModel.newVersionStart.versionString
        VStack(spacing: Spacing.small) {
            Image(systemName: "doc")
                .font(.largeTitle.bold())
                .foregroundStyle(Palette.label3)
                .accessibilityHidden(true)
            Text("No version to edit")
                .font(.title3.weight(.semibold))
            Group {
                if let queued {
                    Text("Version \(queued.versionString) waits in Review & Push. Push it to edit its version texts here.")
                } else {
                    Text("Version \(live) is live and read-only. Create version \(next) to edit version texts.")
                }
            }
            .font(.callout)
            .foregroundStyle(Palette.label2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 460)
            .accessibilityIdentifier("storePage.noVersion.message")
            Text("Name, Subtitle and Privacy Policy URL are app-level and stay editable.")
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
            HStack(spacing: Spacing.small) {
                if queued == nil, viewModel.canCreateVersion {
                    Button("Create Version \(next)…") { viewModel.openNewVersion() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("storePage.createVersion")
                    Link(destination: Self.appStoreConnectURL(appID: viewModel.app.id)) {
                        Text("Open App Store Connect")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Link(destination: Self.appStoreConnectURL(appID: viewModel.app.id)) {
                        Text("Open App Store Connect")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("View Version \(live)") {
                    viewModel.showsReadOnlyVersion = true
                }
                .accessibilityIdentifier("storePage.viewLiveVersion")
            }
            .padding(.top, Spacing.xxSmall)
        }
        .padding(Spacing.xxLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("storePage.noVersion")
    }

    /// "1.4" after "1.3", "2.0.1" after "2.0.0": the last number plus one.
    static func nextVersion(after version: String) -> String {
        NewAppVersion.next(after: version)
    }

    static func appStoreConnectURL(appID: StoreApp.ID) -> URL {
        URL(string: "https://appstoreconnect.apple.com/apps/\(appID)/distribution") ?? URL(filePath: "/")
    }
}

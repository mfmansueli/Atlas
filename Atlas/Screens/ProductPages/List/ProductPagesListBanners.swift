//
//  ProductPagesListBanners.swift
//  Atlas
//

import SwiftUI

/// What stops new pages, above the list: Apple's limit of 70, being
/// offline (the list is the last read, edits are kept), or a key whose
/// role can read pages and can't change them.
struct ProductPagesListBanners: View {
    @Bindable var viewModel: ProductPagesViewModel

    @Environment(\.openSettings) private var openSettings
    /// Nil in previews.
    @Environment(AppSession.self) private var session: AppSession?

    var body: some View {
        if viewModel.isOffline {
            Banner(
                kind: .offline,
                title: String(localized: "You’re offline."),
                message: String(localized: """
                As of \(readTime). Edits stay on this Mac until you can push.
                """)
            ) {
                Button("Try Again") {
                    Task { await viewModel.load(force: true) }
                }
                .accessibilityIdentifier("pages.offline.retry")
            }
            .accessibilityIdentifier("pages.banner.offline")
        }
        if viewModel.keyCannotChange {
            Banner(kind: .warning, title: String(localized: "Your key can read product pages and can’t change them."), message: roleMessage) {
                Button("Open Settings") {
                    SettingsNavigation.shared.pane = .accounts
                    openSettings()
                }
                .accessibilityIdentifier("pages.norole.settings")
            }
            .accessibilityIdentifier("pages.banner.norole")
        }
        if viewModel.isAtLimit {
            Banner(
                kind: .warning,
                title: String(localized: "\(viewModel.app.name) has \(viewModel.pageCount) pages, the most Apple allows."),
                message: String(localized: "Delete one to make another. Hidden and rejected pages count.")
            ) {
                Button(viewModel.showsOnlyHiddenAndRejected ? "Show All Pages" : "Show Hidden and Rejected") {
                    viewModel.showsOnlyHiddenAndRejected.toggle()
                }
                .accessibilityIdentifier("pages.limit.filter")
            }
            .accessibilityIdentifier("pages.banner.limit")
        }
    }

    private var readTime: String {
        (viewModel.snapshot?.readAt ?? .now).formatted(date: .omitted, time: .shortened)
    }

    private var roleMessage: String {
        let needs = String(localized: "Making and editing pages needs the Admin, App Manager or Marketing role.")
        guard let keyID = session?.currentKeyID else { return needs }
        return String(localized: "Key \(keyID) can’t make or change them. \(needs)")
    }
}

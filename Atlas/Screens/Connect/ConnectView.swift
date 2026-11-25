//
//  ConnectView.swift
//  Atlas
//

import SwiftUI
import UniformTypeIdentifiers

/// First launch (and after the last key is removed): asks for a team API
/// key (Issuer ID, Key ID and the `.p8` private key), checks it with App
/// Store Connect and hands it to `AppSession`, which saves it in the
/// Keychain. "Add Another Key…" shows the same form in a sheet, under the
/// same compact header, with Cancel (the canvas's Welcome `addkey`).
/// Rewritten 22 November (README-Welcome): "Before you start" makes the key
/// in three steps, "Then paste it here" takes the three things from it.
struct ConnectView: View {
    @State private var viewModel: ConnectViewModel
    @State private var isImportingKey = false
    @FocusState private var focusedField: ConnectViewModel.Field?
    /// Shown above the form, e.g. why the saved keys couldn't be loaded.
    private let notice: String?
    /// Set in the "Add Another Key…" sheet.
    private let onCancel: (() -> Void)?
    /// Set under the welcome header (board 45): Back returns to Welcome,
    /// and the header above already shows the icon.
    private let onBack: (() -> Void)?
    private let startsWithDropHover: Bool
    /// "Add Another Key…" while a team is connected: the team that stays,
    /// which the header names.
    private let keptTeam: String?
    /// DEBUG scenes start the check as the view appears.
    private let startsConnecting: Bool
    /// Under the welcome header the window's size, in the sheet the
    /// sheet's, decides what hides and whether the cards sit side by side
    /// (README-Welcome). Nil shows everything.
    private let layout: WelcomeLayout?

    init(
        checker: any KeyChecker,
        notice: String? = nil,
        onCancel: (() -> Void)? = nil,
        onBack: (() -> Void)? = nil,
        keptTeam: String? = nil,
        layout: WelcomeLayout? = nil,
        prefill: (@MainActor (ConnectViewModel) -> Void)? = nil,
        startsConnecting: Bool = false,
        onConnect: @escaping (AppStoreConnectCredentials, KeyAccessCheck) throws -> Void
    ) {
        let viewModel = ConnectViewModel(checker: checker, onConnect: onConnect)
        prefill?(viewModel)
        self.init(
            viewModel: viewModel,
            notice: notice,
            onCancel: onCancel,
            onBack: onBack,
            keptTeam: keptTeam,
            layout: layout,
            startsConnecting: startsConnecting
        )
    }

    /// With an existing model: under the welcome header, and for DEBUG
    /// scenes and previews, optionally with a file hovering over the drop
    /// zone.
    init(
        viewModel: ConnectViewModel,
        notice: String? = nil,
        onCancel: (() -> Void)? = nil,
        onBack: (() -> Void)? = nil,
        keptTeam: String? = nil,
        layout: WelcomeLayout? = nil,
        showsDropHover: Bool = false,
        startsConnecting: Bool = false
    ) {
        _viewModel = State(initialValue: viewModel)
        self.layout = layout
        self.notice = notice
        self.onCancel = onCancel
        self.onBack = onBack
        self.keptTeam = keptTeam
        startsWithDropHover = showsDropHover
        self.startsConnecting = startsConnecting
    }

    var body: some View {
        Group {
            // "Add Another Key…": the check gets its own step, with Cancel
            // back to the filled form (the canvas's `addkey-check`).
            if let keptTeam, viewModel.isVerifying {
                AddKeyCheckingView(keptTeam: keptTeam, layout: sheetLayout) { viewModel.cancelConnect() }
            } else if isSheet {
                // The sheet draws the welcome's compact header itself; in
                // the window, `WelcomeFlowView` does.
                VStack(spacing: 0) {
                    WelcomeHeader(style: .compact, markSize: sheetLayout.compactMarkSize)
                        .frame(height: sheetLayout.compactHeaderHeight)
                    page
                }
            } else {
                page
            }
        }
        .onChange(of: focusedField) { oldValue, _ in
            if let oldValue { viewModel.leave(oldValue) }
        }
        // After the edit, not inside it: the field only picks up a change
        // made in a later update.
        .onChange(of: viewModel.keyID) { viewModel.uppercaseKeyID() }
        .fileImporter(isPresented: $isImportingKey, allowedContentTypes: [.appStoreConnectPrivateKey, .data]) { result in
            switch result {
            case let .success(url): importKey(at: url)
            case let .failure(error): viewModel.importFailed(error)
            }
        }
        .task {
            if startsConnecting { viewModel.startConnect() }
        }
    }

    private var page: some View {
        ScrollView {
            VStack(spacing: showsExplanations ? Spacing.large : Spacing.medium) {
                title
                if let notice {
                    InlineMessage.warning(notice)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                cards
                // Under the fields, where the person fixes it (board 45).
                if let failure = viewModel.failure {
                    ConnectFailureBanner(failure: failure) { viewModel.startConnect() }
                }
                footer
            }
            .frame(maxWidth: 820)
            .padding(.horizontal, Spacing.xxxLarge)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center, for: .alignment)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var isSheet: Bool { onCancel != nil }

    /// The sheet's layout, or the preferred sheet's when none was given.
    private var sheetLayout: WelcomeLayout {
        layout ?? WelcomeLayout(windowSize: AddKeySheetLayout.preferred)
    }

    /// Below 680 points of height only the steps and the fields stay.
    private var showsExplanations: Bool { layout?.showsConnectExplanations ?? true }

    /// Below 900 points of width the hints beside the field names hide.
    private var showsFieldHints: Bool { layout?.showsFieldHints ?? true }

    private var verticalPadding: CGFloat {
        if onBack == nil, !isSheet { return Spacing.xxxLarge }
        return showsExplanations ? Spacing.xLarge : Spacing.medium
    }

    /// Under the header: the step (in the sheet, "Another App Store Connect
    /// team"), the title and what the key is for, no tile (the header is
    /// the icon).
    private var title: some View {
        VStack(spacing: Spacing.xxSmall) {
            if let eyebrow {
                Text(eyebrow)
                    .atlasTextStyle(.subheadline)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.accentText)
                    .accessibilityIdentifier(isSheet ? "connect.eyebrow" : "connect.step")
            }
            Text(titleKey)
                .atlasTextStyle(showsExplanations ? .largeTitle : .title1)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("connect.title")
            if showsExplanations {
                subtitle
                    .atlasTextStyle(.title3)
                    .fontWeight(.regular)
                    .foregroundStyle(Palette.label2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 520)
                    .accessibilityIdentifier("connect.subtitle")
            }
        }
    }

    private var titleKey: LocalizedStringKey {
        isSheet ? "Add Another Key" : "Connect to App Store Connect"
    }

    /// "Step 1 of 2" on first launch; in the sheet, while another team
    /// stays connected, "Another App Store Connect team".
    private var eyebrow: String? {
        guard isSheet else { return String(localized: "Step 1 of 2", comment: "kind:label") }
        return keptTeam.map { _ in AddKeyCopy.eyebrow }
    }

    /// In the sheet, the team that stays connected and where to switch.
    private var subtitle: Text {
        if isSheet, let keptTeam { return Text(AddKeyCopy.subtitle(keeping: keptTeam)) }
        return Text("Atlas uses an App Store Connect key to read your apps and push what you approve. You do this once.")
    }

    /// Before you start, then the fields: side by side, as in the window
    /// and the "Add Another Key…" sheet's design, one over the other only
    /// in a sheet too narrow for both.
    @ViewBuilder
    private var cards: some View {
        if layout?.placesCardsSideBySide ?? true {
            EqualHeightRow(spacing: Spacing.large) {
                beforeYouStart
                fields
            }
        } else {
            VStack(spacing: Spacing.medium) {
                beforeYouStart
                fields
            }
        }
    }

    private var beforeYouStart: some View {
        ConnectBeforeYouStart(showsExplanation: showsExplanations)
    }

    private var fields: some View {
        ConnectKeyFields(
            viewModel: viewModel,
            focusedField: $focusedField,
            showsExplanation: showsExplanations,
            showsHints: showsFieldHints,
            startsWithDropHover: startsWithDropHover,
            onChooseFile: { isImportingKey = true },
            onDrop: importKey(at:)
        )
    }

    private var footer: some View {
        HStack(spacing: Spacing.large) {
            ConnectTrustNote()
            Spacer(minLength: Spacing.small)
            if let onCancel {
                Button("Cancel", action: onCancel)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("connect.cancelButton")
            }
            if let onBack {
                Button("Back", action: onBack)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("connect.backButton")
            }
            Button {
                viewModel.startConnect()
            } label: {
                HStack(spacing: Spacing.xSmall) {
                    if viewModel.isVerifying {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isVerifying ? "Checking…" : "Connect")
                }
                .frame(minWidth: 84)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canConnect)
            .accessibilityIdentifier("connect.connectButton")
        }
        .padding(.horizontal, Spacing.xSmall)
    }

    private func importKey(at url: URL) {
        do {
            try viewModel.importKey(PrivateKeyFileReader.read(url))
        } catch CocoaError.fileReadInapplicableStringEncoding {
            // Not text at all, so certainly not a PEM key.
            viewModel.importKey(ImportedPrivateKey(fileName: url.lastPathComponent, pem: ""))
        } catch {
            viewModel.importFailed(error)
        }
    }
}

#Preview {
    ConnectView(checker: LiveKeyChecker()) { _, _ in }
        .frame(width: 1000, height: 760)
}

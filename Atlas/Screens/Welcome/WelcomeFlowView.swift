//
//  WelcomeFlowView.swift
//  Atlas
//

import SwiftUI

/// The first run (board 45), in place of the old connect screen: Welcome,
/// with the icon moving in the top half of the window; Get Started opens
/// Connect, which keeps the header at a fifth of the window over the same
/// three fields; Back returns to Welcome. Saving the key hands over to
/// the main window's "Reading your apps…".
struct WelcomeFlowView: View {
    let checker: any KeyChecker
    var notice: String?
    /// DEBUG scenes show the Reduce Motion header without the setting.
    var forcesStill = false
    let onConnect: (AppStoreConnectCredentials, KeyAccessCheck) throws -> Void

    @State private var stage: WelcomeStage
    /// Kept across Back and Get Started, so what was typed stays.
    @State private var connect: ConnectViewModel

    init(
        checker: any KeyChecker,
        notice: String? = nil,
        stage: WelcomeStage? = nil,
        viewModel: ConnectViewModel? = nil,
        forcesStill: Bool = false,
        onConnect: @escaping (AppStoreConnectCredentials, KeyAccessCheck) throws -> Void
    ) {
        self.checker = checker
        self.notice = notice
        self.forcesStill = forcesStill
        self.onConnect = onConnect
        _stage = State(initialValue: stage ?? WelcomeStage.initial(hasNotice: notice != nil))
        _connect = State(initialValue: viewModel ?? ConnectViewModel(checker: checker, onConnect: onConnect))
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = WelcomeLayout(windowSize: geometry.size)
            VStack(spacing: 0) {
                WelcomeHeader(
                    style: stage == .welcome ? .large : .compact,
                    markSize: stage == .welcome ? layout.largeMarkSize : layout.compactMarkSize,
                    forcesStill: forcesStill
                )
                .frame(height: stage == .welcome ? layout.largeHeaderHeight : layout.compactHeaderHeight)
                switch stage {
                case .welcome:
                    WelcomeIntro(layout: layout) { go(to: .connect) }
                        .transition(.opacity)
                case .connect:
                    ConnectView(viewModel: connect, notice: notice, onBack: { go(to: .welcome) }, layout: layout)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .navigationTitle("Atlas")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(stage == .welcome ? "welcome.view" : "connect.view")
    }

    private func go(to stage: WelcomeStage) {
        withAnimation(.smooth(duration: 0.35)) { self.stage = stage }
    }
}

#Preview {
    WelcomeFlowView(checker: LiveKeyChecker()) { _, _ in }
        .frame(width: 1200, height: 780)
}

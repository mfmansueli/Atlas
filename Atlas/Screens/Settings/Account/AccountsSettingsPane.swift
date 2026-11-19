//
//  AccountsSettingsPane.swift
//  Atlas
//

import SwiftUI

/// Settings → Accounts (board 48): every saved key with its role and what
/// that role can't do, Test Connection, Remove… (asked in place, on that
/// key) and Add Another Key…; then the vendor number Analytics reads sales
/// with. Right-click a key to use it or rename it; the API doesn't share
/// team names, so each key is named here.
struct AccountsSettingsPane: View {
    @Environment(AppSession.self) private var session
    @Environment(\.keyChecker) private var keyChecker
    @Environment(ProGate.self) private var pro: ProGate?
    @State private var viewModel: AccountSettingsViewModel?
    @State private var removing: String?
    @State private var renaming: AppStoreConnectCredentials?
    @State private var draftName = ""
    @State private var isAddingKey = false

    init(removingKeyID: String? = nil) {
        _removing = State(initialValue: removingKeyID)
    }

    var body: some View {
        Form {
            SettingsPaneHeader(pane: .accounts)
            if let viewModel {
                keysSection(viewModel)
                AccountsSalesSection(session: session)
            }
        }
        .formStyle(.grouped)
        .task {
            if viewModel == nil { viewModel = AccountSettingsViewModel(session: session, checker: keyChecker) }
        }
        .alert("Rename Key", isPresented: isRenaming, presenting: renaming) { credentials in
            TextField(viewModel?.teamNameFromAppStoreConnect(for: credentials.keyID) ?? String(localized: "Team name"), text: $draftName)
            Button("Rename") { viewModel?.rename(keyID: credentials.keyID, to: draftName) }
            Button("Cancel", role: .cancel) {}
        } message: { credentials in
            Text(renameMessage(for: credentials.keyID))
        }
        .sheet(isPresented: $isAddingKey) {
            AddKeySheet()
        }
    }

    private func keysSection(_ viewModel: AccountSettingsViewModel) -> some View {
        Section {
            if viewModel.keys.isEmpty {
                Text("No keys yet. Connect one from the main window, or add one here.")
                    .foregroundStyle(Palette.label2)
            }
            ForEach(viewModel.keys, id: \.keyID) { credentials in
                row(credentials, viewModel: viewModel)
                if removing == credentials.keyID {
                    AccountRemovalPanel(
                        name: viewModel.account(for: credentials).name, appCount: viewModel.check(for: credentials.keyID)?.appCount
                    ) {
                        removing = nil
                    } onRemove: {
                        removing = nil
                        viewModel.remove(keyID: credentials.keyID)
                    }
                }
            }
            addKeyRow(viewModel)
        } header: {
            Text("App Store Connect keys")
        }
    }

    private func row(_ credentials: AppStoreConnectCredentials, viewModel: AccountSettingsViewModel) -> some View {
        let keyID = credentials.keyID
        return SavedKeyRow(
            credentials: credentials,
            account: viewModel.account(for: credentials),
            isInUse: viewModel.isInUse(keyID),
            isTesting: viewModel.isTesting(keyID),
            check: viewModel.check(for: keyID),
            failure: viewModel.failure(for: keyID),
            onTest: { Task { await viewModel.test(keyID: keyID) } },
            onRemove: { removing = keyID }
        )
        .contextMenu {
            Button("Use This Key") { viewModel.use(keyID: keyID) }
                .disabled(viewModel.isInUse(keyID))
            Button("Rename…") {
                draftName = credentials.teamName ?? ""
                renaming = credentials
            }
            Divider()
            Button("Remove…", role: .destructive) { removing = keyID }
        }
    }

    private func addKeyRow(_ viewModel: AccountSettingsViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.small) {
                Button {
                    isAddingKey = true
                } label: {
                    Label("Add Another Key…", systemImage: "plus")
                }
                .accessibilityIdentifier("settings.addKey")
                if pro?.isFree == true {
                    Text("More than one account is part of Atlas Pro.")
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                        .accessibilityIdentifier("settings.addKey.pro")
                }
            }
            if let message = viewModel.errorMessage {
                InlineMessage.error(message)
            }
        }
    }

    private func renameMessage(for keyID: String) -> String {
        guard let name = viewModel?.teamNameFromAppStoreConnect(for: keyID) else {
            return String(localized: "App Store Connect didn’t give this team’s name, so give this key the name you know it by.")
        }
        return String(localized: "Leave it empty to use “\(name)”, the team’s name in App Store Connect.")
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }
}

//
//  AccountsSheet.swift
//  Atlas
//

import SwiftUI

/// Accounts and keys (Redesign, 23 November), from the app menu's Switch
/// Account or Key…: each saved key with its team, In use beside the one
/// open and Switch beside the others; Add Another Key…, Manage Keys in
/// Settings… and Done. Switching signs nothing out.
struct AccountsSheet: View {
    let accounts: [TeamAccount]
    let currentAccountID: TeamAccount.ID?
    /// How many apps the open team has, for its row; nil says nothing.
    var currentAppCount: Int?
    let onSwitch: (TeamAccount) -> Void
    let onAddKey: () -> Void
    let onManageKeys: () -> Void
    /// Free with a key saved: Add Another Key… carries the PRO chip.
    var addKeyNeedsPro = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(String(localized: "Accounts and keys", comment: "kind:sheet-title"))
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(String(
                    localized: "Each key opens one App Store Connect team. Switch to see that team’s apps; nothing is signed out.",
                    comment: "kind:sheet-body"
                ))
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.top, Spacing.xLarge)
            .padding(.bottom, Spacing.medium)
            VStack(spacing: 0) {
                ForEach(accounts) { account in
                    Divider()
                    KeyRow(
                        account: account,
                        detail: AccountsSheetText.detail(
                            for: account, appCount: account.id == currentAccountID ? currentAppCount : nil
                        ),
                        isCurrent: account.id == currentAccountID
                    ) {
                        dismiss()
                        onSwitch(account)
                    }
                }
                Divider()
                HStack(spacing: Spacing.small) {
                    Button {
                        dismiss()
                        onAddKey()
                    } label: {
                        HStack(spacing: Spacing.xSmall) {
                            Label(String(localized: "Add Another Key…", comment: "kind:button"), systemImage: "plus")
                            if addKeyNeedsPro { ProChip() }
                        }
                    }
                    .accessibilityIdentifier("accounts.addKey")
                    Text(String(localized: "Another team, a client’s account, or a new key for this one.", comment: "kind:hint"))
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, Spacing.small)
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.bottom, Spacing.medium)
            Divider()
            HStack(spacing: Spacing.small) {
                Button(String(localized: "Manage Keys in Settings…", comment: "kind:button")) {
                    dismiss()
                    onManageKeys()
                }
                .plainButton()
                .accessibilityIdentifier("accounts.manageKeys")
                Spacer()
                Button(String(localized: "Done", comment: "kind:button")) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("accounts.done")
            }
            .buttonBorderShape(.capsule)
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.medium)
        }
        .frame(width: 520)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("accounts.sheet")
    }

    /// One key: the team's tile, its name over its role, key and apps, then
    /// In use or Switch.
    private struct KeyRow: View {
        let account: TeamAccount
        let detail: String
        let isCurrent: Bool
        let onSwitch: () -> Void

        var body: some View {
            HStack(spacing: 10) {
                InitialsTile(initials: account.initials, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isCurrent {
                    Pill(text: String(localized: "In use", comment: "kind:pill"), style: .increase)
                } else {
                    Button(String(localized: "Switch", comment: "kind:button"), action: onSwitch)
                        .rowActionButton()
                        .accessibilityIdentifier("accounts.switch.\(account.id)")
                }
            }
            .padding(.vertical, 10)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("accounts.key.\(account.id)")
        }
    }
}

#Preview {
    AccountsSheet(
        accounts: [
            TeamAccount(id: "2X9R4HXF34", name: "Northpier Studio", role: "Admin"),
            TeamAccount(id: "7QK2M8ZP1D", name: "Fieldworks Studio", role: "App Manager"),
        ],
        currentAccountID: "2X9R4HXF34", currentAppCount: 6, onSwitch: { _ in }, onAddKey: {}, onManageKeys: {}
    )
}

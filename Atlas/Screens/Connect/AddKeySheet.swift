//
//  AddKeySheet.swift
//  Atlas
//

import SwiftUI

/// "Add Another Key…" from the app menu, the account switcher or Settings →
/// Account: the connect form in a sheet. While a team is connected, a key
/// that checks out is saved beside it and the sheet asks: keep that team,
/// or switch to the new one (the canvas's Welcome `addkey` scenes). With no
/// key in use, it becomes the key in use, as on first launch.
struct AddKeySheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.keyChecker) private var keyChecker
    @Environment(\.teamNameLookup) private var teamNameLookup
    @Environment(\.dismiss) private var dismiss
    @State private var added: AddedKey?
    private let prefill: (@MainActor (ConnectViewModel) -> Void)?

    /// DEBUG scenes open straight on the done step, or with the form
    /// filled in.
    init(added: AddedKey? = nil, prefill: (@MainActor (ConnectViewModel) -> Void)? = nil) {
        _added = State(initialValue: added)
        self.prefill = prefill
    }

    var body: some View {
        Group {
            if let added {
                AddKeyDoneView(added: added) {
                    dismiss()
                } onSwitch: {
                    session.select(keyID: added.keyID)
                    dismiss()
                }
            } else {
                form
            }
        }
        .frame(width: 580, height: 680)
    }

    private var form: some View {
        let kept = session.account?.name
        return ConnectView(
            checker: TeamNamingKeyChecker(base: keyChecker, lookup: teamNameLookup),
            onCancel: { dismiss() },
            keptTeam: kept,
            prefill: prefill,
            onConnect: { credentials, check in
                guard let kept else {
                    try session.connect(credentials, check: check)
                    dismiss()
                    return
                }
                try session.add(credentials, check: check)
                added = AddedKey(keyID: credentials.keyID, check: check, keptTeam: kept)
            }
        )
    }
}

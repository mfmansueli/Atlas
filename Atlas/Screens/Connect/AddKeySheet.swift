//
//  AddKeySheet.swift
//  Atlas
//

import SwiftUI

/// "Add Another Key…" from the app menu, the account switcher or Settings →
/// Account: the first launch's Connect in a sheet (the canvas's Redesign
/// `addkey` sheet, Welcome's `addkey` scenes): the compact welcome
/// header, "Before you start" beside "Then paste it here", Cancel and
/// Connect. 920 × 700, smaller in a smaller window so it always fits inside
/// it (`AddKeySheetLayout`). While a team is connected, a key is checked
/// on a step of its own (Cancel goes back to the form), one that checks out
/// is saved beside it and the sheet asks: keep that team, or switch to the
/// new one. With no key in use, it becomes the key in use, as on first
/// launch.
struct AddKeySheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.keyChecker) private var keyChecker
    @Environment(\.teamNameLookup) private var teamNameLookup
    @Environment(\.dismiss) private var dismiss
    @State private var added: AddedKey?
    @State private var size = AddKeySheetLayout.current
    private let prefill: (@MainActor (ConnectViewModel) -> Void)?
    private let startsChecking: Bool

    /// DEBUG scenes open straight on the done step, or with the form
    /// filled in (and, for `addkey-check`, the check started).
    init(added: AddedKey? = nil, prefill: (@MainActor (ConnectViewModel) -> Void)? = nil, startsChecking: Bool = false) {
        _added = State(initialValue: added)
        self.prefill = prefill
        self.startsChecking = startsChecking
    }

    var body: some View {
        let layout = WelcomeLayout(windowSize: size)
        Group {
            if let added {
                AddKeyDoneView(added: added, layout: layout) {
                    dismiss()
                } onSwitch: {
                    session.select(keyID: added.keyID)
                    dismiss()
                }
            } else {
                form(layout: layout)
            }
        }
        .frame(width: size.width, height: size.height)
        // Follows the window it's over, so a smaller window keeps it inside.
        .background(SheetParentSizeReader { window in
            let fitting = AddKeySheetLayout.size(fitting: window)
            if fitting != size { size = fitting }
        })
    }

    private func form(layout: WelcomeLayout) -> some View {
        let kept = session.account?.name
        return ConnectView(
            checker: TeamNamingKeyChecker(base: keyChecker, lookup: teamNameLookup),
            onCancel: { dismiss() },
            keptTeam: kept,
            layout: layout,
            prefill: prefill,
            startsConnecting: startsChecking,
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

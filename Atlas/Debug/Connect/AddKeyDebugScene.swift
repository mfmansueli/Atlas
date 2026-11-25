//
//  AddKeyDebugScene.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// `addkey`, `addkey-403`, `addkey-check` and `addkey-done`: the library with "Add Another
/// Key…" open over it, Northpier Studio's key in use in the sheet's own
/// session (`ConnectDebugScenes`).
struct AddKeyDebugScene: View {
    let id: String
    @State private var session = AppSession(store: DebugCredentialsStore(keys: [
        AppStoreConnectCredentials(
            issuerID: DebugFixtures.issuerID,
            keyID: DebugFixtures.keyID,
            privateKeyPEM: DebugFixtures.privateKey.pem,
            teamName: DebugFixtures.northpier.name
        ),
    ]))
    @State private var isPresented = true

    var body: some View {
        DebugMainScene()
            .sheet(isPresented: $isPresented) {
                AddKeySheet(added: id == "addkey-done" ? Self.added : nil, prefill: Self.fill, startsChecking: id == "addkey-check")
                    .environment(session)
            }
    }

    /// Fieldworks Studio's key, as a person who just made it pastes it.
    private static func fill(_ model: ConnectViewModel) {
        model.issuerID = "7c2e19a4-55d0-4b1e-9f3a-2d7e60b8c913"
        model.importKey(ImportedPrivateKey(fileName: "AuthKey_7QK2M8ZP1D.p8", pem: DebugFixtures.privateKey.pem))
    }

    private static var added: AddedKey {
        AddedKey(
            keyID: "7QK2M8ZP1D",
            check: KeyAccessCheck(
                appCount: 3, milliseconds: 164, salesAccess: .readable, date: .now,
                appNames: ["Trailhead", "Ledgerly", "Kiln"], teamName: ConnectDebugScenes.addedTeamName
            ),
            keptTeam: DebugFixtures.northpier.name
        )
    }
}
#endif

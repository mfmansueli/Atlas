//
//  AppInformationServices+RecentBuilds.swift
//  Atlas
//

import Foundation

extension AppInformationServices {
    /// No builds: nothing to tell from them.
    func recentBuilds(for _: StoreApp) async -> [EncryptionKeyBuild] {
        []
    }
}

extension LiveAppInformationServices {
    /// The app's newest uploads, for whether they arrive with their
    /// encryption answer set. A read that fails only leaves that out.
    func recentBuilds(for app: StoreApp) async -> [EncryptionKeyBuild] {
        guard let resources = try? await client.recentBuilds(appID: app.id) else { return [] }
        return resources.map(EncryptionKeyBuild.init)
    }
}

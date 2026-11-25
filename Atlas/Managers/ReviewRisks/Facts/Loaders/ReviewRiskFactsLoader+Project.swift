//
//  ReviewRiskFactsLoader+Project.swift
//  Atlas
//

import Foundation

extension ReviewRiskFactsLoader {
    /// The app's project folder, read off the main actor with the folder's
    /// sandbox access (`ClaudeCodeLauncher.readProjectFolder`). Nil without a
    /// launcher, without a folder chosen in Settings → AI Assistants, or when
    /// the folder can't be opened: the project checks then say so.
    func projectFacts(for app: StoreApp) async -> ReviewRiskProjectFacts? {
        guard let launcher else { return nil }
        let facts = await launcher.readProjectFolder(for: app.id) { folder in
            ReviewRiskProjectReader.read(folder: folder)
        }
        return facts ?? nil
    }
}

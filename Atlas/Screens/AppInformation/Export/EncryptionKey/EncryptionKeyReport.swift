//
//  EncryptionKeyReport.swift
//  Atlas
//

import Foundation

/// What an assistant did about the export compliance key in the app's
/// project: `report_encryption_key`. Kept per app (`EncryptionKeyStore`);
/// the card on Export Compliance shows it ("Added in project.pbxproj
/// (Lumen) — builds uploaded from now on answer it"), or the problem and
/// Try Again.
struct EncryptionKeyReport: Hashable, Codable, Sendable {
    enum Status: String, Hashable, Codable, CaseIterable, Sendable {
        /// The assistant changed the project.
        case added
        /// The project already had the key with this value.
        case alreadyThere
        case couldNotAdd
    }

    /// One place the key is set: a file, at a line or as a build setting,
    /// for a target and its configurations.
    struct Place: Hashable, Codable, Sendable {
        var file: String
        var line: Int?
        var buildSetting: String?
        var target: String
        var configurations: [String] = []

        /// "Lumen/Info.plist:42", "project.pbxproj · INFOPLIST_KEY_… (Debug, Release)".
        var text: String {
            var text = line.map { "\(file):\($0)" } ?? file
            if let buildSetting { text += " · \(buildSetting)" }
            if !configurations.isEmpty { text += " (\(configurations.joined(separator: ", ")))" }
            return "\(text) — \(target)"
        }

        /// "project.pbxproj".
        var fileName: String {
            (file as NSString).lastPathComponent
        }
    }

    var appID: StoreApp.ID
    var status: Status
    /// What the key says; nil for couldNotAdd without one.
    var value: EncryptionKeyValue?
    /// `ITSEncryptionExportComplianceCode`, with YES.
    var code: String?
    var places: [Place] = []
    /// The commit, when the project's instructions say changes are
    /// committed.
    var commit: String?
    /// Why it couldn't be added.
    var reason: String?
    var notes: String?
    /// "Claude Code".
    var client: String
    var date: Date

    /// The key is in the project.
    var isDone: Bool { status != .couldNotAdd && value != nil }

    /// The card's line: "Added in project.pbxproj (Lumen) — builds uploaded
    /// from now on answer it", "Already in Info.plist (Lumen) — …",
    /// "Claude Code couldn't add it".
    var headline: String {
        let place = places.first.map { String(localized: "\($0.fileName) (\($0.target))") }
        switch status {
        case .added:
            guard let place else { return String(localized: "Added to the project — builds uploaded from now on answer it") }
            return String(localized: "Added in \(place) — builds uploaded from now on answer it")
        case .alreadyThere:
            guard let place else { return String(localized: "Already in the project — builds uploaded from now on answer it") }
            return String(localized: "Already in \(place) — builds uploaded from now on answer it")
        case .couldNotAdd:
            return String(localized: "\(client) couldn’t add it")
        }
    }

    /// "By Claude Code · Nov 23, 2026 at 10:42 · commit a1b2c3d".
    func byLine(_ format: Date.FormatStyle = .dateTime.month(.abbreviated).day().year().hour().minute()) -> String {
        var parts = [String(localized: "By \(client)"), date.formatted(format)]
        if let commit, !commit.isEmpty { parts.append(String(localized: "commit \(String(commit.prefix(10)))")) }
        return parts.joined(separator: " · ")
    }
}

//
//  EncryptionKeyProjectReader.swift
//  Atlas
//

import Foundation

/// Reads whether an app's project sets the export compliance key: the
/// Xcode projects in its folder (up to two folders down), their app
/// targets building `bundleID` (else the only app target), and in each its
/// Release build settings, then the Info.plist `INFOPLIST_FILE` names.
enum EncryptionKeyProjectReader {
    static func read(folder: URL, bundleID: String?, fileManager: FileManager = .default) -> EncryptionKeyProjectState {
        guard fileManager.isReadableFile(atPath: folder.path(percentEncoded: false)) else {
            return .unreadable(reason: String(localized: "Atlas can’t open the project folder. Choose it again."))
        }
        let projects = ProjectFolderCheck.projects(in: folder, depth: 2, fileManager: fileManager).compactMap(XcodeProjectFile.read)
        let apps = projects.flatMap { project in project.targets.filter(\.isApplication).map { (project, $0) } }
        let building = apps.filter { _, target in
            guard let bundleID else { return false }
            return target.value("PRODUCT_BUNDLE_IDENTIFIER")?.caseInsensitiveCompare(bundleID) == .orderedSame
        }
        let chosen = building.isEmpty && apps.count == 1 ? apps : building
        guard !chosen.isEmpty else {
            return .unreadable(reason: String(localized: "Atlas found no app target building this app’s bundle ID in the project folder."))
        }
        for (project, target) in chosen {
            if let key = key(of: target, in: project) { return .found(key) }
        }
        return .notFound(targets: chosen.map(\.1.name))
    }

    /// The key in `target`'s build settings, else in its Info.plist.
    static func key(of target: XcodeProjectFile.Target, in project: XcodeProjectFile) -> EncryptionKeyProjectState.Key? {
        let setting = "INFOPLIST_KEY_\(EncryptionKeyAnswer.key)"
        if let text = target.value(setting), let value = EncryptionKeyValue(text: text) {
            let code = target.value("INFOPLIST_KEY_\(EncryptionKeyAnswer.codeKey)").flatMap { $0.isEmpty ? nil : $0 }
            return .init(value: value, code: code, target: target.name, location: setting, isBuildSetting: true)
        }
        guard let path = target.value("INFOPLIST_FILE"), !path.isEmpty,
              let data = try? Data(contentsOf: project.file(path)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        let value: EncryptionKeyValue? = switch plist[EncryptionKeyAnswer.key] {
        case let flag as Bool: EncryptionKeyValue(usesNonExemptEncryption: flag)
        case let text as String: EncryptionKeyValue(text: text)
        default: nil
        }
        guard let value else { return nil }
        let code = (plist[EncryptionKeyAnswer.codeKey] as? String).map { XcodeProjectFile.expand($0, settings: target.settings) }
        return .init(value: value, code: code, target: target.name, location: path, isBuildSetting: false)
    }
}

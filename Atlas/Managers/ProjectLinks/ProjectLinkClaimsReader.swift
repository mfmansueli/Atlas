//
//  ProjectLinkClaimsReader.swift
//  Atlas
//

import Foundation

/// Reads which links an app's project claims, without an assistant: the
/// app targets of the Xcode projects in its folder (up to two folders
/// down), the ones that build `bundleID` first, then each one's Info.plist
/// URL schemes and its entitlements' `applinks:` domains. A target whose
/// Info.plist is generated from build settings alone has no URL schemes:
/// those can only be declared in an Info.plist file.
enum ProjectLinkClaimsReader {
    static func read(folder: URL, bundleID: String?, fileManager: FileManager = .default) -> ProjectLinkClaimsState {
        let path = folder.path(percentEncoded: false)
        guard fileManager.isReadableFile(atPath: path) else {
            return .unreadable(folder: path, reason: String(localized: "Atlas can’t open the project folder. Choose it again."))
        }
        let projects = ProjectFolderCheck.projects(in: folder, depth: 2, fileManager: fileManager).compactMap(XcodeProjectFile.read)
        guard !projects.isEmpty else {
            return .unreadable(folder: path, reason: String(localized: "Atlas found no Xcode project in the project folder."))
        }
        let apps = projects.flatMap { project in project.targets.filter(\.isApplication).map { (project, $0) } }
        let building = apps.filter { _, target in
            guard let bundleID else { return false }
            return target.value("PRODUCT_BUNDLE_IDENTIFIER")?.caseInsensitiveCompare(bundleID) == .orderedSame
        }
        let iOSApps = apps.filter(\.1.isIOS)
        let chosen = !building.isEmpty ? building : !iOSApps.isEmpty ? iOSApps : apps
        guard !chosen.isEmpty else {
            return .unreadable(folder: path, reason: String(localized: "Atlas found no app target in the project folder’s Xcode projects."))
        }
        var claims = ProjectLinkClaims()
        for (project, target) in chosen {
            claims.targets.append(target.name)
            claims.schemes.formUnion(schemes(of: target, in: project))
            claims.domains.formUnion(domains(of: target, in: project))
            if claims.build == nil, let version = target.value("MARKETING_VERSION"), !version.isEmpty {
                let number = target.value("CURRENT_PROJECT_VERSION") ?? ""
                claims.build = number.isEmpty ? version : "\(version) (\(number))"
            }
        }
        return .read(folder: path, claims: claims)
    }

    /// `CFBundleURLTypes`' `CFBundleURLSchemes`, lowercased, with build
    /// settings filled in (`$(PRODUCT_BUNDLE_IDENTIFIER)`).
    static func schemes(of target: XcodeProjectFile.Target, in project: XcodeProjectFile) -> Set<String> {
        guard let path = target.value("INFOPLIST_FILE"), !path.isEmpty,
              let plist = dictionary(at: project.file(path)),
              let types = plist["CFBundleURLTypes"] as? [[String: Any]]
        else { return [] }
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        return Set(schemes.map { XcodeProjectFile.expand($0, settings: target.settings).lowercased() }.filter { !$0.isEmpty })
    }

    /// The hosts after `applinks:` in `com.apple.developer.associated-domains`,
    /// lowercased, without `?mode=developer`.
    static func domains(of target: XcodeProjectFile.Target, in project: XcodeProjectFile) -> Set<String> {
        guard let path = target.value("CODE_SIGN_ENTITLEMENTS"), !path.isEmpty,
              let entitlements = dictionary(at: project.file(path)),
              let domains = entitlements["com.apple.developer.associated-domains"] as? [String]
        else { return [] }
        return Set(domains.compactMap { entry -> String? in
            let expanded = XcodeProjectFile.expand(entry, settings: target.settings)
            guard expanded.lowercased().hasPrefix("applinks:") else { return nil }
            let host = expanded.dropFirst("applinks:".count).split(separator: "?").first.map(String.init) ?? ""
            return host.isEmpty ? nil : host.lowercased()
        })
    }

    private static func dictionary(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }
}

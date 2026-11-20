//
//  XcodeProjectFile.swift
//  Atlas
//

import Foundation

/// An Xcode project's targets and their build settings, read from its
/// `project.pbxproj` (an old-style property list, which
/// `PropertyListSerialization` reads). Each target's settings are its
/// Release configuration's over the project's, with `$(SETTING)`
/// references filled in as far as the file tells.
struct XcodeProjectFile: Hashable, Sendable {
    struct Target: Hashable, Sendable {
        var name: String
        /// `com.apple.product-type.application`.
        var productType: String
        var settings: [String: String]

        var isApplication: Bool { productType == "com.apple.product-type.application" }

        /// Built for iPhone or iPad: its SDK or supported platforms say so.
        var isIOS: Bool {
            let sdk = settings["SDKROOT"]?.lowercased() ?? ""
            let platforms = settings["SUPPORTED_PLATFORMS"]?.lowercased() ?? ""
            return sdk.hasPrefix("iphoneos") || platforms.contains("iphoneos")
        }

        /// A setting with every reference in it filled in.
        func value(_ key: String) -> String? {
            settings[key].map { XcodeProjectFile.expand($0, settings: settings) }
        }
    }

    /// The folder the `.xcodeproj` is in: `$(SRCROOT)`.
    var sourceRoot: URL
    var targets: [Target]

    /// Reads `project` (the `.xcodeproj` package); nil when it isn't one.
    static func read(_ project: URL) -> XcodeProjectFile? {
        guard let data = try? Data(contentsOf: project.appending(path: "project.pbxproj")),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let objects = plist["objects"] as? [String: [String: Any]],
              let rootID = plist["rootObject"] as? String, let root = objects[rootID]
        else { return nil }
        let sourceRoot = project.deletingLastPathComponent()
        let projectSettings = settings(of: root["buildConfigurationList"] as? String, in: objects)
        let targets = (root["targets"] as? [String] ?? []).compactMap { id -> Target? in
            guard let target = objects[id], let name = target["name"] as? String else { return nil }
            var settings = projectSettings
            settings.merge(Self.settings(of: target["buildConfigurationList"] as? String, in: objects)) { _, own in own }
            settings["TARGET_NAME"] = name
            if settings["PRODUCT_NAME"] == nil { settings["PRODUCT_NAME"] = name }
            let root = sourceRoot.path(percentEncoded: false)
            for key in ["SRCROOT", "PROJECT_DIR", "SOURCE_ROOT"] where settings[key] == nil { settings[key] = root }
            return Target(name: name, productType: target["productType"] as? String ?? "", settings: settings)
        }
        return XcodeProjectFile(sourceRoot: sourceRoot, targets: targets)
    }

    /// A configuration list's Release settings (else its first), with
    /// conditional ones (`KEY[sdk=iphoneos*]`) under their plain key when
    /// that has none.
    private static func settings(of listID: String?, in objects: [String: [String: Any]]) -> [String: String] {
        guard let listID, let list = objects[listID], let ids = list["buildConfigurations"] as? [String] else { return [:] }
        let configurations = ids.compactMap { objects[$0] }
        let chosen = configurations.first { ($0["name"] as? String) == "Release" } ?? configurations.first
        let raw = chosen?["buildSettings"] as? [String: Any] ?? [:]
        var settings: [String: String] = [:]
        for (key, value) in raw.sorted(by: { $0.key < $1.key }) {
            let text: String? = switch value {
            case let string as String: string
            case let array as [String]: array.joined(separator: " ")
            default: nil
            }
            guard let text else { continue }
            if let bracket = key.firstIndex(of: "[") {
                let plain = String(key[..<bracket])
                if raw[plain] == nil, settings[plain] == nil { settings[plain] = text }
            } else {
                settings[key] = text
            }
        }
        return settings
    }

    /// `$(PRODUCT_BUNDLE_IDENTIFIER)`, `${TARGET_NAME}` and
    /// `$(PRODUCT_NAME:rfc1034identifier)` filled in from `settings`;
    /// `$(inherited)` and unknown ones are dropped.
    static func expand(_ text: String, settings: [String: String], depth: Int = 0) -> String {
        guard depth < 8, text.contains("$") else { return text }
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            guard character == "$", next < text.endIndex, text[next] == "(" || text[next] == "{" else {
                result.append(character)
                index = next
                continue
            }
            let close: Character = text[next] == "(" ? ")" : "}"
            guard let end = text[next...].firstIndex(of: close) else {
                result.append(contentsOf: text[index...])
                break
            }
            let reference = String(text[text.index(after: next)..<end])
            let parts = reference.split(separator: ":", maxSplits: 1).map(String.init)
            let name = parts.first ?? ""
            var value = name == "inherited" ? "" : expand(settings[name] ?? "", settings: settings, depth: depth + 1)
            if parts.count > 1, parts[1].hasPrefix("rfc1034identifier") {
                value = String(value.map { $0.isLetter || $0.isNumber || $0 == "." ? $0 : "-" })
            } else if parts.count > 1, parts[1].hasPrefix("lower") {
                value = value.lowercased()
            }
            result += value
            index = text.index(after: end)
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// A path setting (`Alba/Info.plist`, `$(SRCROOT)/Alba/Alba.entitlements`)
    /// as a file URL.
    func file(_ path: String) -> URL {
        path.hasPrefix("/") ? URL(filePath: path) : sourceRoot.appending(path: path)
    }
}

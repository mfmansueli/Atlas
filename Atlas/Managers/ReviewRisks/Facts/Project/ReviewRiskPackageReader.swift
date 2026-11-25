//
//  ReviewRiskPackageReader.swift
//  Atlas
//

import Foundation

/// The app's dependencies by name, lowercased, from the files that pin
/// them: Package.resolved (versions 1, 2 and 3), Podfile.lock and
/// Cartfile.resolved. Each gives every name it has for a dependency (the
/// identity, the package name, the repository's name), so a check can look
/// for any of them.
enum ReviewRiskPackageReader {
    /// Package.resolved: version 1's `object.pins[].package` and
    /// `repositoryURL`, versions 2 and 3's `pins[].identity` and `location`.
    static func packageResolved(_ data: Data) -> Set<String> {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let pins = json["pins"] as? [[String: Any]] ?? (json["object"] as? [String: Any])?["pins"] as? [[String: Any]] ?? []
        var names: Set<String> = []
        for pin in pins {
            for key in ["identity", "package"] {
                if let name = pin[key] as? String, !name.isEmpty { names.insert(name.lowercased()) }
            }
            for key in ["location", "repositoryURL"] {
                if let location = pin[key] as? String, let name = repositoryName(location) { names.insert(name) }
            }
        }
        return names
    }

    /// Podfile.lock: the pods under `PODS:` ("  - FBSDKLoginKit (16.0.1):"),
    /// with a subspec's pod too ("Firebase/Auth" gives "firebase/auth" and
    /// "firebase").
    static func podfileLock(_ text: String) -> Set<String> {
        var names: Set<String> = []
        var inPods = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if !line.hasPrefix(" ") {
                inPods = line.trimmingCharacters(in: .whitespaces) == "PODS:"
                continue
            }
            guard inPods, line.hasPrefix("  - ") else { continue }
            var name = line.dropFirst(4).trimmingCharacters(in: .whitespaces)
            if name.hasPrefix("\"") { name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            if let space = name.firstIndex(of: " ") { name = String(name[..<space]) }
            if name.hasSuffix(":") { name = String(name.dropLast()) }
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            guard !name.isEmpty else { continue }
            names.insert(name.lowercased())
            if let slash = name.firstIndex(of: "/") { names.insert(String(name[..<slash]).lowercased()) }
        }
        return names
    }

    /// Cartfile.resolved: `github "facebook/facebook-ios-sdk" "v16.0.0"`,
    /// `git "…"` and `binary "…/Name.json"`: the repository's name.
    static func cartfileResolved(_ text: String) -> Set<String> {
        var names: Set<String> = []
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "\"")
            guard parts.count >= 2 else { continue }
            var source = String(parts[1])
            if source.hasSuffix(".json") { source = String(source.dropLast(5)) }
            if let name = repositoryName(source) { names.insert(name) }
        }
        return names
    }

    /// "https://github.com/google/GoogleSignIn-iOS.git" → "googlesignin-ios".
    static func repositoryName(_ location: String) -> String? {
        var trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        if trimmed.lowercased().hasSuffix(".git") { trimmed = String(trimmed.dropLast(4)) }
        let name = trimmed.split(whereSeparator: { $0 == "/" || $0 == ":" }).last.map(String.init) ?? ""
        return name.isEmpty ? nil : name.lowercased()
    }
}

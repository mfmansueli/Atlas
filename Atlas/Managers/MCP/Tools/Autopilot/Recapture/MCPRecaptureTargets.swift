//
//  MCPRecaptureTargets.swift
//  Atlas
//

import Foundation

/// What `request_recapture` names, as a plan's capture targets: each item
/// of `targets` is a screen (its ID, name or number) or a set's slot (from
/// 1, as list_captures numbers them), in a locale, on a device (every
/// device that captures it when left out), and on iPhone Duo in a pose
/// (both when left out). An item without screen or slot is every screen
/// in that locale. What can't be matched comes back with why. With no
/// saved run the plan comes from the set's captures, and only what the set
/// has a capture of can be redone (`Captured`): "Alba has no captures in ja
/// on ipad". Pure.
struct MCPRecaptureTargets {
    var targets: [AutopilotCaptureTarget] = []
    var refused: [JSONValue] = []

    /// The targets the set has captures of, and whose they are, when the
    /// plan was made from them.
    struct Captured {
        var appName: String
        var targets: Set<AutopilotCaptureTarget>

        /// "Alba has no captures in ja", "… in ja on ipad".
        func refusal(locale: String, display: ScreenshotDisplayType?) -> String {
            guard let display else { return String(localized: "\(appName) has no captures in \(locale).") }
            return String(localized: "\(appName) has no captures in \(locale) on \(display.mcpValue).")
        }
    }

    init(_ items: [JSONValue], plan: AutopilotPlan, captured: Captured? = nil) {
        var found: Set<AutopilotCaptureTarget> = []
        for item in items {
            switch Self.targets(item, plan: plan, captured: captured) {
            case let .success(targets): found.formUnion(targets)
            case let .failure(refusal): refused.append(refusal.json(item))
            }
        }
        targets = plan.targets.filter(found.contains)
    }

    private struct Refusal: Error {
        var reason: String

        func json(_ item: JSONValue) -> JSONValue {
            var json: [String: JSONValue] = ["reason": .string(reason)]
            for key in ["screen", "slot", "locale", "displayType", "pose"] {
                if let value = item[key], !value.isNull { json[key] = value }
            }
            return .object(json)
        }
    }

    /// An item's locale and devices in the plan, or why they aren't.
    private static func place(
        of item: JSONValue, plan: AutopilotPlan, captured: Captured?
    ) -> Result<(locale: StoreLocale, displays: [ScreenshotDisplayType], display: ScreenshotDisplayType?), Refusal> {
        let code = item["locale"]?.stringValue
        let asked = code.flatMap { StoreLocaleCatalog.resolve($0).locale }
        let display = item["displayType"]?.stringValue.flatMap(ScreenshotDisplayType.init(mcpValue:))
        guard let locale = asked, plan.capturedLocales.contains(locale.code) else {
            if let captured, let code, !code.isEmpty {
                return .failure(Refusal(reason: captured.refusal(locale: asked?.code ?? code, display: display)))
            }
            let list = plan.capturedLocales.joined(separator: ", ")
            return .failure(Refusal(reason: String(localized: "Send one of the plan’s captured locales: \(list).")))
        }
        guard item["displayType"]?.stringValue != nil else { return .success((locale, plan.displayTypes, nil)) }
        guard let display, plan.displayTypes.contains(display) else {
            if let captured, display != nil { return .failure(Refusal(reason: captured.refusal(locale: locale.code, display: display))) }
            let devices = plan.displayTypes.map(\.mcpValue).formatted(.list(type: .or))
            return .failure(Refusal(reason: String(localized: "The plan captures on \(devices).")))
        }
        return .success((locale, [display], display))
    }

    private static func targets(_ item: JSONValue, plan: AutopilotPlan, captured: Captured?) -> Result<[AutopilotCaptureTarget], Refusal> {
        let place: (locale: StoreLocale, displays: [ScreenshotDisplayType], display: ScreenshotDisplayType?)
        switch Self.place(of: item, plan: plan, captured: captured) {
        case let .success(found): place = found
        case let .failure(refusal): return .failure(refusal)
        }
        let (locale, displays, display) = place
        let pose = item["pose"]?.stringValue.flatMap(AutopilotDuoPose.init(rawValue:))
        var inLocale = plan.targets.filter { $0.locale == locale.code && displays.contains($0.displayType) }
        if let pose { inLocale = inLocale.filter { $0.displayType != .iPhoneDuo || plan.duoPose(for: $0) == pose } }
        if let captured {
            // Only what the set has a capture of.
            inLocale = inLocale.filter(captured.targets.contains)
            guard !inLocale.isEmpty else { return .failure(Refusal(reason: captured.refusal(locale: locale.code, display: display))) }
        }
        if let slot = item["slot"]?.intValue {
            let matched = inLocale.filter { AutopilotRecaptureTargets.documentSlot(of: $0, in: plan)?.slot == slot - 1 }
            guard !matched.isEmpty else {
                return .failure(Refusal(reason: String(localized: "No capture on slot \(slot) in \(locale.code) on those devices.")))
            }
            return .success(matched)
        }
        guard let value = item["screen"].flatMap({ $0.stringValue ?? $0.intValue.map(String.init) }), !value.isEmpty else {
            return inLocale.isEmpty
                ? .failure(Refusal(reason: String(localized: "Nothing is captured in \(locale.code) on those devices.")))
                : .success(inLocale)
        }
        let screenIDs = Set(displays.flatMap { display in screens(named: value, on: display, in: plan).map(\.id) })
        let matched = inLocale.filter { screenIDs.contains($0.screenID) }
        guard !matched.isEmpty else {
            let ids = displays.flatMap { plan.screens(on: $0) }.map(\.id)
            var seen: Set<String> = []
            let list = ids.filter { seen.insert($0).inserted }.joined(separator: ", ")
            return .failure(Refusal(reason: String(localized: "The plan has no screen “\(value)” there; its screens are \(list).")))
        }
        return .success(matched)
    }

    /// A device's screens by ID, name or number (from 1).
    static func screens(named value: String, on display: ScreenshotDisplayType, in plan: AutopilotPlan) -> [AutopilotScreen] {
        let screens = plan.screens(on: display)
        if let screen = screens.first(where: { $0.id == value }) { return [screen] }
        if let screen = screens.first(where: { $0.name.localizedCaseInsensitiveCompare(value) == .orderedSame }) { return [screen] }
        if let number = Int(value), screens.indices.contains(number - 1) { return [screens[number - 1]] }
        return []
    }

    /// The App Preview's moments by screen ID or name, and the ones it
    /// doesn't have.
    static func moments(_ values: [String], in run: AutopilotRun) -> (ids: [String], unknown: [String]) {
        let moments = run.pickableMoments.map(\.screenID)
        var ids: [String] = []
        var unknown: [String] = []
        for value in values {
            let named = run.plan.screens.first { $0.name.localizedCaseInsensitiveCompare(value) == .orderedSame }?.id
            if let id = moments.first(where: { $0 == value || $0 == named }) {
                if !ids.contains(id) { ids.append(id) }
            } else {
                unknown.append(value)
            }
        }
        return (ids, unknown)
    }
}

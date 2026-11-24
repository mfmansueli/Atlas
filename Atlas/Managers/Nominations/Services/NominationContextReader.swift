//
//  NominationContextReader.swift
//  Atlas
//

import Foundation

/// Reads a nomination's context from the other sections' services, the
/// same way live and in DEBUG scenes. Each part that fails is left out.
@MainActor
struct NominationContextReader {
    let appList: any AppListServices
    let storePage: any StorePageServices
    let inAppEvents: any InAppEventsServices
    let productPages: any ProductPagesServices

    func context(for app: StoreApp) async -> NominationContext {
        var context = NominationContext()
        context.apps = await (try? appList.apps()) ?? [app]
        if !context.apps.contains(where: { $0.id == app.id }) { context.apps.insert(app, at: 0) }
        context.teamName = await (try? appList.teamName()) ?? nil
        if let content = try? await storePage.content(for: app, versionID: nil) {
            context.locales = content.locales.map(\.code)
            if let version = content.editableVersion {
                context.version = NominationContext.Version(
                    versionString: version.versionString,
                    isFirstVersion: version.listingVersion.isFirstVersion,
                    whatsNew: content.version.id == version.id ? content.texts[content.primaryLocale]?[.whatsNew] ?? "" : ""
                )
            }
        }
        let events = await (try? inAppEvents.events(for: app)) ?? []
        context.events = events.filter { $0.state != .archived }.map(Self.event)
        context.links = [NominationContext.appStoreLink(for: app)]
        if let pages = try? await productPages.pages(for: app) {
            context.links += pages.pages.filter { $0.approved != nil && $0.url != nil }.map { page in
                NominationContext.KnownLink(
                    title: String(localized: "Custom product page · \(page.name)", comment: "kind:field-label"),
                    detail: String(localized: "Approved · \(page.approved?.locales.count ?? 0) languages", comment: "kind:description"),
                    url: page.url?.absoluteString ?? ""
                )
            }
        }
        return context
    }

    nonisolated static func event(_ event: InAppEvent) -> NominationContext.Event {
        let schedule = event.schedule
        var parts: [String] = []
        if let badge = event.badge { parts.append(badge.title) }
        if let start = schedule?.eventStart {
            let range = schedule?.eventEnd.map { (start..<max(start, $0)).formatted(.interval.month(.abbreviated).day()) }
            parts.append(range ?? start.formatted(.dateTime.month(.abbreviated).day()))
        }
        if event.state.isOver { parts.append(String(localized: "Ended", comment: "kind:pill")) }
        return NominationContext.Event(
            id: event.id,
            name: event.referenceName,
            detail: parts.joined(separator: " · "),
            start: schedule?.eventStart,
            isOver: event.state.isOver,
            shortDescription: event.primaryLocalization?.shortDescription ?? ""
        )
    }
}

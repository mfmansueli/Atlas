//
//  TranslationsDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Board 77: what a suggestion in another language means, and how natural
/// it sounds (`TranslationsDebugData`).
/// - `nat-de`: German What's New sounds translated, two phrases marked;
///   keywords with MEANS only. `nat-de-use`: after Use Natural Version.
/// - `nat-pl`: the Polish subtitle sounds off, MEANS marks "inspirations";
///   `nat-pl-use`: its natural version.
/// - `nat-ja`: Japanese, Sounds native. `nat-he`: Hebrew, right to left.
/// - `nat-sh-fr`, `nat-sh-de`: Screenshots captions in French and German.
/// - `nat-all`, `nat-all-de`: Accept All Languages on Polish and German;
///   what sounds off starts unticked.
/// - `nat-en`: English (U.S.), the interface language: nothing new.
enum TranslationsDebugScenes {
    static let ids = [
        "nat-de", "nat-de-use", "nat-pl", "nat-pl-use", "nat-ja", "nat-he", "nat-sh-fr", "nat-sh-de", "nat-all", "nat-all-de", "nat-en",
    ]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "nat-de": storePage { $0.openEditor(.german) }
        case "nat-de-use": storePage(using: .whatsNew, in: .german)
        case "nat-pl": storePage { $0.openEditor(.polish) }
        case "nat-pl-use": storePage(using: .subtitle, in: .polish)
        case "nat-ja": storePage { $0.openEditor(.japanese) }
        case "nat-he": storePage { $0.openEditor(.hebrew) }
        case "nat-en": storePage { $0.openEditor(.englishUS) }
        case "nat-all", "nat-all-de":
            storePage { model in
                model.openEditor(id == "nat-all" ? .polish : .german)
                model.sheet = .acceptAll
            }
        case "nat-sh-fr", "nat-sh-de": captions(locale: id == "nat-sh-fr" ? "fr-FR" : "de-DE")
        default: nil
        }
    }

    // MARK: - Store Page

    @MainActor
    private static func storePage(using field: ListingField, in locale: StoreLocale) -> AnyView {
        storePage { model in
            model.openEditor(locale)
            if let suggestion = model.shownSuggestion(field, in: locale) { model.useNaturalVersion(suggestion) }
        }
    }

    @MainActor
    private static func storePage(opening: @escaping @MainActor (StorePageViewModel) async -> Void) -> AnyView {
        var storePage = DebugStorePageServices()
        storePage.appSupport = DebugAppSupport.center()
        storePage.opening = DebugStorePageServices.Opening(opening)
        var services = WorkspaceServices.debug
        services.storePage = storePage
        return SuggestionsDebugScenes.with(.connected, DebugMainScene(services: services, section: .storePage, suggestions: TranslationsDebugData.store()))
    }

    // MARK: - Screenshots

    @MainActor
    private static func captions(locale code: String) -> AnyView {
        let center = ScreenshotsDocumentCenter.shared
        center.diskStore = nil
        let opening = ScreenshotsDebugOpening { model in
            if var document = model.document {
                document.proposals.append(TranslationsDebugData.captionProposal)
                await model.commit(document)
            }
            model.pageLocale = StoreLocaleCatalog.locale(code: code)
        }
        let screenshots = DebugScreenshotsServices(scenario: .standard, opening: opening, documentCenter: center)
        screenshots.opensLanguagePage = true
        var storePage = DebugStorePageServices()
        storePage.screenshots = screenshots
        var services = WorkspaceServices.debug
        services.storePage = storePage
        return SuggestionsDebugScenes.with(.connected, DebugMainScene(services: services, section: .screenshots, pendingChanges: DebugWorkspace.pendingChanges))
    }
}
#endif

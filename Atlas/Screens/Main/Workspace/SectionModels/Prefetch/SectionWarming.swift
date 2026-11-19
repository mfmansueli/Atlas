//
//  SectionWarming.swift
//  Atlas
//

import Foundation

/// How `SectionPrefetcher` reads one app's sections ahead: whether a
/// section has anything to read, and the read itself, made the way the
/// section makes it when it opens, so opening it afterwards finds a
/// loaded model.
@MainActor
protocol SectionWarming: Sendable {
    /// True when `section` has no model yet, never finished a read, or
    /// what it read is old.
    func needsWarming(_ section: AppWorkspaceSection, of app: StoreApp, kept: AppSectionModels, refreshCount: Int) -> Bool

    /// Makes `section`'s model when there is none, reads it, and stamps it
    /// in `kept` when the read worked.
    func warm(_ section: AppWorkspaceSection, of app: StoreApp, kept: AppSectionModels, refreshCount: Int) async
}

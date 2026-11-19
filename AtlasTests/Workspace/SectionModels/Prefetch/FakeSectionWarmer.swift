//
//  FakeSectionWarmer.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// A `SectionWarming` that notes the sections it reads; the ones in
/// `fresh` have nothing to read. `onWarm` runs inside each read.
@MainActor
final class FakeSectionWarmer: SectionWarming {
    private(set) var warmed: [AppWorkspaceSection] = []
    var fresh: Set<AppWorkspaceSection> = []
    var onWarm: (AppWorkspaceSection) async -> Void = { _ in }

    init(fresh: Set<AppWorkspaceSection> = []) {
        self.fresh = fresh
    }

    func needsWarming(_ section: AppWorkspaceSection, of _: StoreApp, kept _: AppSectionModels, refreshCount _: Int) -> Bool {
        !fresh.contains(section)
    }

    func warm(_ section: AppWorkspaceSection, of _: StoreApp, kept: AppSectionModels, refreshCount: Int) async {
        warmed.append(section)
        await onWarm(section)
        kept.didLoad(section, refreshCount: refreshCount)
    }
}

//
//  RefreshSectionProgress.swift
//  Atlas
//

import Foundation

/// Where the open section's read for a Refresh stands, as its kept model
/// shows it (`AppSectionModels.refreshProgress(of:refreshCount:)`).
enum RefreshSectionProgress: Hashable, Sendable {
    /// Still reading, or not started yet.
    case reading
    /// The read ended well.
    case done
    /// The read ended with this error, as the section shows it.
    case failed(String)
}

//
//  FunnelGap+Problem.swift
//  Atlas
//

import Foundation

extension FunnelGap {
    /// Something the person can fix (amber), not data on its way.
    var isProblem: Bool {
        actionTitle != nil
    }
}

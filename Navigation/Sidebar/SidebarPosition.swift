//
//  SidebarPosition.swift
//  Nook
//
//  Shared sidebar placement model extracted from the removed slideout menu UI.
//

import Foundation

public enum SidebarPosition: String, CaseIterable, Identifiable {
    case left
    case right

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left:
            return "Left"
        case .right:
            return "Right"
        }
    }

    var icon: String {
        switch self {
        case .left:
            return "sidebar.left"
        case .right:
            return "sidebar.right"
        }
    }
}

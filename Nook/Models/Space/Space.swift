//
//  Space.swift
//  Nook
//
//  Created by Maciek Bagiński on 04/08/2025.
//

import AppKit
import SwiftUI
 
// Gradient configuration for spaces
// See: SpaceGradient.swift

struct SpaceSettingsDraft {
    var name: String
    var icon: String
    var profileId: UUID?
    var usesSeparateProfile: Bool
    var isWorkspaceIncognito: Bool
}

@MainActor
@Observable
public class Space: NSObject, Identifiable {
    public let id: UUID
    var name: String
    var icon: String
    var color: NSColor
    var gradient: SpaceGradient
    var activeTabId: UUID?
    var profileId: UUID?
    var usesSeparateProfile: Bool = false
    var isWorkspaceIncognito: Bool = false
    
    /// Whether this space belongs to an ephemeral/incognito profile
    var isEphemeral: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "square.grid.2x2",
        color: NSColor = .controlAccentColor,
        gradient: SpaceGradient = .default,
        profileId: UUID? = nil,
        usesSeparateProfile: Bool = false,
        isWorkspaceIncognito: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.gradient = gradient
        self.activeTabId = nil
        self.profileId = profileId
        self.usesSeparateProfile = usesSeparateProfile
        self.isWorkspaceIncognito = isWorkspaceIncognito
        super.init()
    }
}

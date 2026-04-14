//
//  SidebarHeader.swift
//  Nook
//
//  Created by Aether on 15/11/2025.
//

import SwiftUI

/// Header section of the sidebar (window controls, navigation buttons, URL bar)
struct SidebarHeader: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(CommandPalette.self) private var commandPalette
    @Environment(\.nookSettings) var nookSettings
    let isSidebarHovered: Bool
    @State private var sidebarWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 8) {
            windowControls

            if !nookSettings.topBarAddressView {
                navigationButtons
                urlBar
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            sidebarWidth = newWidth
        }
    }

    private var windowControls: some View {
        SidebarWindowControlsView()
            .environmentObject(browserManager)
            .environment(windowState)
            .environment(commandPalette)
            .padding(.horizontal, 8)
    }

    private var navigationButtons: some View {
        HStack(spacing: 2) {
            NavButtonsView(effectiveSidebarWidth: sidebarWidth)
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
    }

    private var urlBar: some View {
        URLBarView(isSidebarHovered: isSidebarHovered)
            .padding(.horizontal, 8)
    }
}

// MARK: - Sidebar Window Controls (Top Bar Mode)
struct SidebarWindowControlsView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(CommandPalette.self) private var commandPalette
    @Environment(\.nookSettings) var nookSettings

    var body: some View {
        HStack(spacing: 6) {
            if nookSettings.sidebarPosition == .left {
                MacButtonsView()
                    .frame(width: 70)
            }

            Button("Toggle Sidebar", systemImage: nookSettings.sidebarPosition == .left ? "sidebar.left" : "sidebar.right") {
                browserManager.toggleSidebar(for: windowState)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(NavButtonStyle())
            .foregroundStyle(Color.primary)

            SidebarWorkspaceActionButtons(showSidebarToggle: false)
                .environmentObject(browserManager)
                .environment(windowState)
                .environment(commandPalette)

            Spacer()

            if nookSettings.sidebarPosition == .right {
                MacButtonsView()
                    .frame(width: 70)
            }
        }
        .frame(height: 28)
    }
}

struct SidebarWorkspaceActionButtons: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(CommandPalette.self) private var commandPalette
    @Environment(\.nookSettings) private var nookSettings

    var showSidebarToggle: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            if showSidebarToggle {
                Button("Toggle Sidebar", systemImage: nookSettings.sidebarPosition == .left ? "sidebar.left" : "sidebar.right") {
                    browserManager.toggleSidebar(for: windowState)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(NavButtonStyle())
                .foregroundStyle(Color.primary)
            }

            Button("Clean Up Workspace", systemImage: "sparkles") {
                presentCleanupDialog()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(NavButtonStyle())
            .foregroundStyle(Color.primary)
            .disabled(currentSpace == nil || cleanupCandidateCount == 0)

            Button("Open Search", systemImage: "magnifyingglass") {
                commandPalette.open()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(NavButtonStyle())
            .foregroundStyle(Color.primary)
        }
    }

    private var currentSpace: Space? {
        if let space = windowState.currentSpace {
            return space
        }
        guard let currentSpaceId = windowState.currentSpaceId else {
            return browserManager.tabManager.currentSpace
        }
        return browserManager.tabManager.spaces.first(where: { $0.id == currentSpaceId })
    }

    private var cleanupCandidateCount: Int {
        guard let currentSpace else { return 0 }
        return browserManager.tabManager.cleanupCandidateTabs(for: currentSpace.id).count
    }

    private func presentCleanupDialog() {
        guard let currentSpace else { return }

        let candidateCount = browserManager.tabManager.cleanupCandidateTabs(for: currentSpace.id).count
        let lockedCount = browserManager.tabManager.lockedRegularTabCount(for: currentSpace.id)

        browserManager.dialogManager.showDialog(
            WorkspaceCleanupDialog(
                workspaceName: currentSpace.name,
                workspaceIcon: currentSpace.icon,
                candidateCount: candidateCount,
                lockedCount: lockedCount,
                onConfirm: {
                    _ = browserManager.tabManager.completeUnlockedTabs(for: currentSpace.id)
                    browserManager.dialogManager.closeDialog()
                },
                onCancel: {
                    browserManager.dialogManager.closeDialog()
                }
            )
        )
    }
}

//
//  SpacesSideBarView.swift
//  Nook
//
//  Created by Maciek Bagiński on 30/07/2025.
//  Refactored by Aether on 15/11/2025.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import Sparkle

struct SpacesSideBarView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(WindowRegistry.self) private var windowRegistry
    @Environment(\.nookSettings) var nookSettings
    @Environment(CommandPalette.self) var commandPalette
    @Environment(\.colorScheme) private var colorScheme

    // Space navigation
    @State private var activeSpaceIndex: Int = 0
    @State private var activeTabRefreshTrigger: Bool = false

    // Hover states
    @State private var isSidebarHovered: Bool = false

    var body: some View {
        mainSidebarContent
            .contentShape(Rectangle())
            .onHover { state in
                print("hovering: \(state)")
                isSidebarHovered = state
            }
            .contextMenu {
                sidebarContextMenu
            }
    }

    // MARK: - Main Content

    @ObservedObject private var dragSession = NookDragSessionManager.shared

    private var mainSidebarContent: some View {
        let effectiveProfileId = windowState.currentProfileId ?? browserManager.currentProfile?.id
        let essentialsCount = effectiveProfileId.map { browserManager.tabManager.essentialTabs(for: $0).count } ?? 0
        let shouldAnimate = (windowRegistry.activeWindow?.id == windowState.id) && !browserManager.isTransitioningProfile

        return HStack(spacing: SidebarLayoutMetrics.shellSpacing) {
            if nookSettings.sidebarPosition == .left {
                sidebarRail
                sidebarContentPanel(effectiveProfileId: effectiveProfileId)
            } else {
                sidebarContentPanel(effectiveProfileId: effectiveProfileId)
                sidebarRail
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: LexonTheme.panelCornerRadius, style: .continuous)
                .fill(LexonTheme.sidebarShell(for: colorScheme))
        )
        .overlay {
            RoundedRectangle(cornerRadius: LexonTheme.panelCornerRadius, style: .continuous)
                .stroke(LexonTheme.border(for: colorScheme), lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: LexonTheme.panelCornerRadius, style: .continuous))
        .shadow(color: LexonTheme.shadow(for: colorScheme), radius: 16, x: 0, y: 8)
        .padding(SidebarLayoutMetrics.shellPadding)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        updateSidebarScreenFrame(geo)
                    }
                    .onChange(of: geo.frame(in: .global)) { _, _ in
                        updateSidebarScreenFrame(geo)
                    }
            }
        )
        .animation(
            shouldAnimate ? .easeInOut(duration: 0.18) : nil,
            value: essentialsCount
        )
    }

    private func sidebarContentPanel(effectiveProfileId: UUID?) -> some View {
        VStack(spacing: 14) {
            SidebarHeader(isSidebarHovered: isSidebarHovered, showMacButtons: false)
                .environmentObject(browserManager)
                .environment(windowState)

            if !windowState.isIncognito {
                PinnedGrid(
                    width: windowState.sidebarContentWidth,
                    profileId: effectiveProfileId
                )
                .environmentObject(browserManager)
                .environment(windowState)
                .padding(.horizontal, SidebarLayoutMetrics.panelInset)
                .modifier(FallbackDropBelowEssentialsModifier())
            }

            ZStack {
                spacesPageView
                    .zIndex(1)

                Color.clear
                    .contentShape(Rectangle())
                    .conditionalWindowDrag()
                    .frame(minHeight: 40)
                    .zIndex(0)
            }

            SidebarUpdateNotification(downloadsMenuVisible: false)
                .environmentObject(browserManager)
                .environment(windowState)
                .environment(nookSettings)
                .padding(.horizontal, SidebarLayoutMetrics.panelInset)

            MediaControlsView()
                .environmentObject(browserManager)
                .environment(windowState)
                .padding(.horizontal, SidebarLayoutMetrics.panelInset)
                .padding(.bottom, 2)
        }
        .padding(SidebarLayoutMetrics.panelInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebarRail: some View {
        VStack(spacing: 12) {
            railWindowControls

            SpacesList(
                axis: .vertical,
                itemSideLength: LexonTheme.sidebarRailItemSize
            )
            .environmentObject(browserManager)
            .environment(windowState)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if !windowState.isIncognito {
                Button("New Space", systemImage: "plus") {
                    showSpaceCreationDialog()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(
                    SpaceListItemButtonStyle(
                        isActive: false,
                        sideLength: LexonTheme.sidebarRailItemSize
                    )
                )
                .foregroundStyle(LexonTheme.secondaryText(for: colorScheme))
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(width: LexonTheme.sidebarRailWidth)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var railWindowControls: some View {
        if nookSettings.sidebarPosition == .left {
            MacButtonsView()
                .frame(width: LexonTheme.sidebarRailWidth, height: 28, alignment: .leading)
        } else {
            Color.clear
                .frame(height: 28)
        }
    }

    private func updateSidebarScreenFrame(_ geo: GeometryProxy) {
        let frame = geo.frame(in: .global)
        guard let window = windowState.window ?? NSApp.windows.first(where: { $0.isVisible }),
              let contentView = window.contentView else { return }
        let appKitY = contentView.bounds.height - frame.maxY
        let bottomLeft = NSPoint(x: frame.origin.x, y: appKitY)
        let screenBottomLeft = window.convertPoint(toScreen: bottomLeft)
        dragSession.sidebarScreenFrame = CGRect(
            x: screenBottomLeft.x,
            y: screenBottomLeft.y,
            width: frame.width,
            height: frame.height
        )
    }

    // MARK: - Spaces Page View

    private var spacesPageView: some View {
        let spaces = windowState.isIncognito
            ? windowState.ephemeralSpaces
            : browserManager.tabManager.spaces

        return Group {
            if spaces.isEmpty {
                emptyStateView
            } else {
                spacesContent(spaces: spaces)
            }
        }
    }

    private func spacesContent(spaces: [Space]) -> some View {
        PageView(selection: $activeSpaceIndex) {
            ForEach(spaces.indices, id: \.self) { index in
                if index >= 0 && index < spaces.count {
                    makeSpaceView(for: spaces[index], index: index)
                } else {
                    EmptyView()
                }
            }
        }
        .pageViewStyle(.scroll)
        .contentShape(Rectangle())
        .id(activeTabRefreshTrigger)
        .onAppear {
            if let targetIndex = spaces.firstIndex(where: { $0.id == windowState.currentSpaceId }) {
                activeSpaceIndex = targetIndex
            }
            browserManager.setActiveSpace(spaces[0], in: windowState)
        }
        .onChange(of: activeSpaceIndex) { _, newIndex in
            handleSpaceIndexChange(newIndex, spaces: spaces)
        }
        .onChange(of: windowState.currentSpaceId) { _, _ in
            if let targetIndex = spaces.firstIndex(where: { $0.id == windowState.currentSpaceId }) {
                activeSpaceIndex = targetIndex
            }
            activeTabRefreshTrigger.toggle()
        }
        .onChange(of: windowState.sidebarContentWidth) { _, _ in
            activeTabRefreshTrigger.toggle()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            VStack(spacing: 8) {
                Text("No Spaces")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Create a space to start browsing")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            Button(action: showSpaceCreationDialog) {
                Label("Create Space", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Context Menu

    private var sidebarContextMenu: some View {
        Group {
            Button {
                commandPalette.open()
            } label: {
                Label("New Tab", systemImage: "plus")
            }

            Button {
                if let currentSpace = browserManager.tabManager.currentSpace {
                    browserManager.tabManager.createFolder(for: currentSpace.id)
                }
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }

            Divider()

            Menu {
                ForEach(SidebarPosition.allCases) { position in
                    Toggle(isOn: Binding(
                        get: { nookSettings.sidebarPosition == position },
                        set: { _ in nookSettings.sidebarPosition = position }
                    )) {
                        Label(position.displayName, systemImage: position.icon)
                    }
                }
            } label: {
                Label("Position", systemImage: nookSettings.sidebarPosition.icon)
            }
        }
    }

    // MARK: - Helper Functions

    private func handleSpaceIndexChange(_ newIndex: Int, spaces: [Space]) {
        guard newIndex >= 0 && newIndex < spaces.count else {
            print("⚠️ Invalid space index: \(newIndex), spaces count: \(spaces.count)")
            return
        }

        let space = spaces[newIndex]
        print("🎯 Page changed to space: \(space.name) (index: \(newIndex))")

        // Trigger haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)

        // Activate the space
        browserManager.setActiveSpace(space, in: windowState)
    }

    @ViewBuilder
    private func makeSpaceView(for space: Space, index: Int) -> some View {
        VStack(spacing: 0) {
            SpaceView(
                space: space,
                isActive: windowState.currentSpaceId == space.id,
                isSidebarHovered: $isSidebarHovered,
                onActivateTab: { browserManager.selectTab($0, in: windowState) },
                onCloseTab: { _ = browserManager.tabManager.completeTab($0.id) },
                onPinTab: { browserManager.tabManager.pinTab($0) },
                onMoveTabUp: { browserManager.tabManager.moveTabUp($0.id) },
                onMoveTabDown: { browserManager.tabManager.moveTabDown($0.id) },
                onMuteTab: { $0.toggleMute() }
            )
            .environmentObject(browserManager)
            .environment(windowState)
            .environment(commandPalette)
            .environmentObject(browserManager.gradientColorManager)
            .environmentObject(browserManager.splitManager)
            .id(space.id.uuidString + "-w\(Int(windowState.sidebarContentWidth))")
            Spacer()
        }
        .tag(index)
    }

    // MARK: - Dialogs

    private func showSpaceCreationDialog() {
        browserManager.dialogManager.showDialog(
            SpaceCreationDialog(
                onCreate: { draft in
                    let newSpace = browserManager.tabManager.createSpace(from: draft)

                    if let targetIndex = browserManager.tabManager.spaces.firstIndex(where: { $0.id == newSpace.id }) {
                        activeSpaceIndex = targetIndex
                    }

                    browserManager.setActiveSpace(newSpace, in: windowState)

                    browserManager.dialogManager.closeDialog()
                },
                onCancel: {
                    browserManager.dialogManager.closeDialog()
                }
            )
        )
    }

    private func showSpaceEditDialog(mode: SpaceEditDialog.Mode) {
        guard let targetSpace = resolveCurrentSpace() else { return }

        browserManager.dialogManager.showDialog(
            SpaceEditDialog(
                space: targetSpace,
                mode: mode,
                onSave: { draft in
                    browserManager.tabManager.updateSpaceSettings(spaceId: targetSpace.id, using: draft)
                    browserManager.refreshGradientsForSpace(targetSpace, animate: false)
                    browserManager.dialogManager.closeDialog()
                },
                onCancel: {
                    browserManager.dialogManager.closeDialog()
                }
            )
        )
    }

    private func resolveCurrentSpace() -> Space? {
        // For incognito windows, use ephemeral spaces
        if windowState.isIncognito {
            if let currentId = windowState.currentSpaceId {
                return windowState.ephemeralSpaces.first { $0.id == currentId }
            }
            return windowState.ephemeralSpaces.first
        }
        
        if let current = browserManager.tabManager.currentSpace {
            return current
        }
        if let currentId = windowState.currentSpaceId {
            return browserManager.tabManager.spaces.first { $0.id == currentId }
        }
        return browserManager.tabManager.spaces.first
    }
}

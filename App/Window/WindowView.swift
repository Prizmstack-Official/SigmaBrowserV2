//
//  WindowView.swift
//  Nook
//
//  Created by Maciek Bagiński on 30/07/2025.
//  Updated by Aether Aurelia on 15/11/2025.
//

import SwiftUI
import UniversalGlass

/// Main window view that orchestrates the browser UI layout
struct WindowView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(CommandPalette.self) private var commandPalette
    @Environment(WindowRegistry.self) private var windowRegistry
    @Environment(\.nookSettings) var nookSettings
    @StateObject private var hoverSidebarManager = HoverSidebarManager()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            WindowBackground()
                .contextMenu {
                    Button("Customize Space Gradient...") {
                        browserManager.showGradientEditor()
                    }
                    .disabled(browserManager.tabManager.currentSpace == nil)
                }

            SidebarWebViewStack()

            // Hover-reveal Sidebar overlay (slides in over web content)
            SidebarHoverOverlayView()
                .environmentObject(hoverSidebarManager)
                .environment(windowState)

            CommandPaletteView()
            DialogView()

            // Peek overlay for external link previews
            PeekOverlayView()

            // Find bar - always rendered (24/7), visibility controlled via opacity
            FindBarView(findManager: browserManager.findManager)
                .zIndex(10000)

        }
        // System notification toasts - top trailing corner
        .overlay(alignment: .topTrailing) {
            VStack(spacing: 8) {
                // Profile switch toast
                if windowState.isShowingProfileSwitchToast,
                   let toast = windowState.profileSwitchToast
                {
                    ProfileSwitchToastView(toast: toast)
                        .environment(windowState)
                        .environmentObject(browserManager)
                }

                // Tab closure toast
                if browserManager.showTabClosureToast && browserManager.tabClosureToastCount > 0 {
                    TabClosureToast()
                        .environmentObject(browserManager)
                }

                // Copy URL toast
                if windowState.isShowingCopyURLToast {
                    CopyURLToast()
                        .environment(windowState)
                }
                
                // Shortcut conflict toast
                if windowState.isShowingShortcutConflictToast,
                   let conflictInfo = windowState.shortcutConflictInfo
                {
                    ShortcutConflictToast(conflictInfo: conflictInfo)
                        .environment(windowState)
                }
            }
            .padding(10)
            // Animate toast insertions/removals
            .animation(.smooth(duration: 0.25), value: windowState.isShowingProfileSwitchToast)
            .animation(.smooth(duration: 0.25), value: browserManager.showTabClosureToast)
            .animation(.smooth(duration: 0.25), value: windowState.isShowingCopyURLToast)
            .animation(.smooth(duration: 0.25), value: windowState.isShowingShortcutConflictToast)
        }
        // Zoom control popup - separate from system toasts
        .overlay(alignment: .topTrailing) {
            if browserManager.shouldShowZoomPopup {
                ZoomPopupView(
                    zoomManager: browserManager.zoomManager,
                    onZoomIn: { browserManager.zoomInCurrentTab() },
                    onZoomOut: { browserManager.zoomOutCurrentTab() },
                    onZoomReset: { browserManager.resetZoomCurrentTab() },
                    onZoomPresetSelected: { zoomLevel in browserManager.applyZoomLevel(zoomLevel) },
                    onDismiss: { browserManager.shouldShowZoomPopup = false }
                )
                .transition(.scale(scale: 0.0, anchor: .top))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: browserManager.shouldShowZoomPopup)
                .onTapGesture {
                    browserManager.shouldShowZoomPopup = false
                }
                .padding(10)
            }
        }
        // Lifecycle management
        .onAppear {
            hoverSidebarManager.attach(browserManager: browserManager)
            hoverSidebarManager.windowRegistry = windowRegistry
            hoverSidebarManager.nookSettings = nookSettings
            hoverSidebarManager.start()
        }
        .onDisappear {
            hoverSidebarManager.stop()
        }
        // Handle shortcut conflict notifications
        .onReceive(NotificationCenter.default.publisher(for: .shortcutConflictDetected)) { notification in
            if let conflictInfo = notification.userInfo?["conflictInfo"] as? ShortcutConflictInfo,
               conflictInfo.windowId == windowState.id {
                windowState.shortcutConflictInfo = conflictInfo
                windowState.isShowingShortcutConflictToast = true
                
                // Auto-dismiss after 1.5 seconds (slightly longer than the 1s timeout)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if windowState.shortcutConflictInfo?.timestamp == conflictInfo.timestamp {
                        windowState.isShowingShortcutConflictToast = false
                    }
                }
            }
        }
        // Handle shortcut conflict dismissal
        .onReceive(NotificationCenter.default.publisher(for: .shortcutConflictDismissed)) { notification in
            if let windowId = notification.userInfo?["windowId"] as? UUID,
               windowId == windowState.id {
                windowState.isShowingShortcutConflictToast = false
            }
        }
        .environmentObject(browserManager)
        .environmentObject(browserManager.gradientColorManager)
        .environmentObject(browserManager.splitManager)
        .environmentObject(hoverSidebarManager)
        .preferredColorScheme(windowState.gradient.primaryColor.isPerceivedDark ? .dark : .light)
    }

    // MARK: - Layout Components

    @ViewBuilder
    private func WindowBackground() -> some View {
        ZStack {
            BlurEffectView(material: nookSettings.currentMaterial, state: .followsWindowActiveState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            SpaceGradientBackgroundView()
                .opacity(0.45)
            LexonTheme.windowGradientTint(for: colorScheme)
            LexonTheme.windowWash(for: colorScheme)
        }
        .backgroundDraggable()
        .environment(windowState)
    }

    @ViewBuilder
    private func SidebarWebViewStack() -> some View {
        if nookSettings.topBarAddressView {
            WebContent()
                .padding(.horizontal, 8)
        } else {
            let sidebarVisible = windowState.isSidebarVisible
            let sidebarOnRight = nookSettings.sidebarPosition == .right
            let sidebarOnLeft = nookSettings.sidebarPosition == .left
            
            HStack(spacing: 0) {
                if nookSettings.sidebarPosition == .left {
                    SpacesSidebar()
                    WebContent()
                } else {
                    WebContent()
                    SpacesSidebar()
                }
            }
            .padding(.trailing, sidebarVisible && sidebarOnRight ? 0 : 8)
            .padding(.leading, sidebarVisible && sidebarOnLeft ? 0 : 8)
        }
    }

    @ViewBuilder
    private func SpacesSidebar() -> some View {
        if windowState.isSidebarVisible {
            SpacesSideBarView()
                .frame(width: windowState.sidebarWidth)
                .overlay(alignment: nookSettings.sidebarPosition == .left ? .trailing : .leading) {
                    SidebarResizeView()
                        .frame(maxHeight: .infinity)
                        .environmentObject(browserManager)
                        .environment(windowState)
                        .zIndex(2000)
                        .environment(windowState)
                }
                .environmentObject(browserManager)
                .environment(windowState)
                .environment(commandPalette)
                .environmentObject(browserManager.gradientColorManager)
        }
    }

    @ViewBuilder
    private func WebContent() -> some View {
        let cornerRadius = LexonTheme.chromeCornerRadius
        
        let hasTopBar = nookSettings.topBarAddressView
        
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                if hasTopBar {
                    WebsiteLoadingIndicator()
                        .zIndex(3000)
                    
                    TopBarView()
                        .environmentObject(browserManager)
                        .environment(windowState)
                        .zIndex(2500)

                    topBarContentRegion
                        .zIndex(2000)
                } else {
                    WebsiteLoadingIndicator()
                    WebsiteView()
                        .padding(.top, sidebarAlignedTopInset)
                        .zIndex(2000)
                }
            }
        }
        .coordinateSpace(name: "WindowSpace")
        .overlayPreferenceValue(BrowserUtilityPanelButtonFramePreferenceKey.self) { buttonFrames in
            GeometryReader { proxy in
                if let presentedPanel = windowState.presentedUtilityPanel {
                    let panelCenter = BrowserUtilityPanelLayout.center(
                        for: presentedPanel,
                        buttonFrame: buttonFrames[presentedPanel],
                        in: proxy.size,
                        fallbackTopInset: nookSettings.topBarAddressView ? TopBarMetrics.height : BrowserUtilityPanelLayout.windowInset
                    )

                    BrowserUtilityPanelView(panel: presentedPanel)
                        .environmentObject(browserManager)
                        .environment(windowState)
                        .position(panelCenter)
                        .transition(.browserUtilityPanel)
                        .id(presentedPanel)
                        .zIndex(3500)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LexonTheme.chromeFill(for: colorScheme))
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(LexonTheme.border(for: colorScheme), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: LexonTheme.shadow(for: colorScheme), radius: 22, x: 0, y: 12)
    }

    @ViewBuilder
    private var topBarContentRegion: some View {
        HStack(spacing: topBarContentSpacing) {
            if shouldShowInlineSidebar && nookSettings.sidebarPosition == .left {
                inlineSidebar
            }

            WebsiteView()
                .padding(.top, sidebarAlignedTopInset)
                .zIndex(2000)

            if shouldShowInlineSidebar && nookSettings.sidebarPosition == .right {
                inlineSidebar
            }
        }
        .padding(.horizontal, TopBarMetrics.horizontalPadding)
    }

    @ViewBuilder
    private var inlineSidebar: some View {
        SpacesSideBarView(
            showSidebarWindowControls: false,
            showRailWindowControls: false
        )
        .frame(width: windowState.sidebarWidth)
        .overlay(alignment: nookSettings.sidebarPosition == .left ? .trailing : .leading) {
            if windowState.isSidebarVisible {
                SidebarResizeView()
                    .frame(maxHeight: .infinity)
                    .environmentObject(browserManager)
                    .environment(windowState)
                    .zIndex(2000)
            }
        }
        .environmentObject(browserManager)
        .environment(windowState)
        .environment(commandPalette)
        .environmentObject(browserManager.gradientColorManager)
        .transition(
            .move(edge: nookSettings.sidebarPosition == .left ? .leading : .trailing)
                .combined(with: .opacity)
        )
    }

    private var shouldShowInlineSidebar: Bool {
        nookSettings.topBarAddressView && (windowState.isSidebarVisible || hoverSidebarManager.isOverlayVisible)
    }

    private var topBarContentSpacing: CGFloat {
        shouldShowInlineSidebar ? TopBarMetrics.horizontalPadding : 0
    }

    private var sidebarAlignedTopInset: CGFloat {
        if nookSettings.topBarAddressView {
            return shouldShowInlineSidebar ? SidebarLayoutMetrics.shellInsets.top : 0
        }

        return windowState.isSidebarVisible ? SidebarLayoutMetrics.shellInsets.top : 0
    }

    private func websiteColumnClipShape(cornerRadius: CGFloat, hasTopBar: Bool) -> AnyShape {
        if hasTopBar {
            return AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: cornerRadius,
                bottomTrailingRadius: cornerRadius,
                topTrailingRadius: 0,
                style: .continuous
            ))
        } else {
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

// MARK: - Profile Switch Toast View
private struct ProfileSwitchToastView: View {
    let toast: BrowserManager.ProfileSwitchToast
    @Environment(BrowserWindowState.self) private var windowState
    @EnvironmentObject var browserManager: BrowserManager

    var body: some View {
        ToastView {
            HStack {
                Text("Switched to \(toast.toProfile.name)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .padding(4)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.white.opacity(0.4), lineWidth: 1)
                    }
            }
        }
        .transition(.toast)
        .onAppear {
            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                browserManager.hideProfileSwitchToast(for: windowState)
            }
        }
        .onTapGesture {
            browserManager.hideProfileSwitchToast(for: windowState)
        }
    }
}

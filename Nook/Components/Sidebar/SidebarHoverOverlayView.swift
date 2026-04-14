//
//  SidebarHoverOverlayView.swift
//  Nook
//
//  Created by Jonathan Caudill on 2025-09-13.
//

import SwiftUI
import UniversalGlass
import AppKit

struct SidebarHoverOverlayView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @EnvironmentObject var hoverManager: HoverSidebarManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(CommandPalette.self) private var commandPalette
    @Environment(\.nookSettings) var nookSettings
    @Environment(\.colorScheme) private var colorScheme

    private let cornerRadius: CGFloat = 12
    private let horizontalInset: CGFloat = 0
    private let verticalInset: CGFloat = 0

    var body: some View {
        if !nookSettings.topBarAddressView && !windowState.isSidebarVisible {
            collapsedSidebarOverlay
        }
    }

    private var collapsedSidebarOverlay: some View {
        ZStack(alignment: nookSettings.sidebarPosition == .left ? .leading : .trailing) {
            Color.clear
                .frame(width: hoverManager.triggerWidth)
                .contentShape(Rectangle())
                .onHover { isIn in
                    if isIn && !windowState.isSidebarVisible {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            hoverManager.isOverlayVisible = true
                        }
                    }
                    NSCursor.arrow.set()
                }

            if hoverManager.isOverlayVisible {
                sidebarOverlayContent
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: nookSettings.sidebarPosition == .left ? .topLeading : .topTrailing
        )
    }

    private var sidebarOverlayContent: some View {
        SpacesSideBarView(
            showSidebarWindowControls: false,
            showRailWindowControls: false
        )
        .frame(width: windowState.sidebarWidth)
        .environmentObject(browserManager)
        .environment(windowState)
        .environment(commandPalette)
        .environmentObject(browserManager.gradientColorManager)
        .frame(maxHeight: overlayHeight, alignment: .top)
        .background {
            SpaceGradientBackgroundView()
                .environmentObject(browserManager)
                .environmentObject(browserManager.gradientColorManager)
                .environment(windowState)
                .clipShape(.rect(cornerRadius: cornerRadius))

            Rectangle()
                .fill(LexonTheme.sidebarShell(for: colorScheme))
                .universalGlassEffect(
                    .regular.tint(LexonTheme.sidebarShell(for: colorScheme)),
                    in: .rect(cornerRadius: cornerRadius)
                )
        }
        .alwaysArrowCursor()
        .padding(nookSettings.sidebarPosition == .left ? .leading : .trailing, horizontalInset)
        .padding(.top, overlayTopInset)
        .padding(.bottom, verticalInset)
        .transition(
            .move(edge: nookSettings.sidebarPosition == .left ? .leading : .trailing)
                .combined(with: .opacity)
        )
    }

    private var overlayTopInset: CGFloat {
        nookSettings.topBarAddressView ? TopBarMetrics.height : 0
    }

    private var overlayHeight: CGFloat {
        let contentHeight = windowState.window?.contentView?.bounds.height
            ?? NSScreen.main?.visibleFrame.height
            ?? 800
        return max(contentHeight - overlayTopInset, 0)
    }
}

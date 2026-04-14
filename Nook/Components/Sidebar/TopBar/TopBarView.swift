//
//  TopBarView.swift
//  Nook
//
//  Created by Assistant on 23/09/2025.
//

import AppKit
import SwiftUI

enum TopBarMetrics {
    static let height: CGFloat = LexonTheme.topBarHeight
    static let horizontalPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 7
}

struct TopBarView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(CommandPalette.self) private var commandPalette
    @Environment(\.nookSettings) var nookSettings
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var tabWrapper = ObservableTabWrapper()
    @State private var isHovering: Bool = false
    @State private var previousTabId: UUID? = nil

    var body: some View {
        let cornerRadius: CGFloat = {
            if #available(macOS 26.0, *) {
                return 8
            } else {
                return 8
            }
        }()

        let currentTab = browserManager.currentTab(for: windowState)
        let hasPiPControl =
            currentTab?.hasVideoContent == true
            || browserManager.currentTabHasPiPActive()

        ZStack {
            // Main content
            ZStack {
                HStack(spacing: 8) {
                    navigationControls

                    if hasPiPControl, let tab = currentTab {
                        pipButton(for: tab)
                    }

                    urlBar

                    Spacer()

                    extensionsView

                    BrowserUtilityButtonsView(
                        navButtonColor: navButtonColor,
                        spacesWidth: 156
                    )

                }

            }
            .padding(.horizontal, TopBarMetrics.horizontalPadding)
            .padding(.vertical, TopBarMetrics.verticalPadding)
            .frame(maxWidth: .infinity)
            .frame(height: TopBarMetrics.height)
            .background(topBarBackgroundColor)
            .animation(
                shouldAnimateColorChange ? .easeInOut(duration: 0.3) : nil,
                value: topBarBackgroundColor
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: cornerRadius,
                    style: .continuous
                )
            )
            .overlay(alignment: .bottom) {
                // 1px bottom border - lighter when dark, darker when light
                Rectangle()
                    .fill(bottomBorderColor)
                    .frame(height: 1)
                    .animation(
                        shouldAnimateColorChange
                            ? .easeInOut(duration: 0.3) : nil,
                        value: bottomBorderColor
                    )
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(
                        key: URLBarFramePreferenceKey.self,
                        value: geometry.frame(in: .named("WindowSpace"))
                    )
            }
        )
        .onAppear {
            tabWrapper.setContext(
                browserManager: browserManager,
                windowState: windowState
            )
            updateCurrentTab()
            // Initialize previousTabId to current tab so first color change doesn't animate
            previousTabId = browserManager.currentTab(for: windowState)?.id
        }
        .onChange(of: browserManager.currentTab(for: windowState)?.id) {
            oldId,
            newId in
            previousTabId = oldId
            updateCurrentTab()
            // Update previousTabId after a brief delay so next color change within this tab will animate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                previousTabId = newId
            }
        }
        .onChange(
            of: browserManager.currentTab(for: windowState)?.pageBackgroundColor
        ) { _, _ in
            // Color changes will trigger animations automatically via computed properties
        }
        .onChange(
            of: browserManager.currentTab(for: windowState)?
                .topBarBackgroundColor
        ) { _, _ in
            // Top bar color changes will trigger animations automatically via computed properties
        }
        .onReceive(
            Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
        ) { _ in
            updateCurrentTab()
        }
    }

    private var extensionsView: some View {
        HStack(spacing: 4) {
            if let extensionManager = browserManager.extensionManager {
                ExtensionActionView(
                    extensions: extensionManager.installedExtensions
                )
                .environmentObject(browserManager)
            }

        }


    }

    private var navigationControls: some View {
        HStack(spacing: 4) {
            if shouldShowWindowButtonsInTopBar {
                MacButtonsView()
                    .frame(width: 76, height: 28, alignment: .leading)
            }

            sidebarToggleButton

            Button("Go Back", systemImage: "chevron.backward", action: goBack)
                .labelStyle(.iconOnly)
                .buttonStyle(NavButtonStyle())
                .foregroundStyle(navButtonColor)
                .animation(
                    shouldAnimateColorChange ? .easeInOut(duration: 0.3) : nil,
                    value: navButtonColor
                )
                .disabled(!tabWrapper.canGoBack)
                .opacity(tabWrapper.canGoBack ? 1.0 : 0.4)
                .contextMenu {
                    NavigationHistoryContextMenu(
                        historyType: .back,
                        windowState: windowState
                    )
                }

            Button(
                "Go Forward",
                systemImage: "chevron.right",
                action: goForward
            )
            .labelStyle(.iconOnly)
            .buttonStyle(NavButtonStyle())
            .foregroundStyle(navButtonColor)
            .animation(
                shouldAnimateColorChange ? .easeInOut(duration: 0.3) : nil,
                value: navButtonColor
            )
            .disabled(!tabWrapper.canGoForward)
            .opacity(tabWrapper.canGoForward ? 1.0 : 0.4)
            .contextMenu {
                NavigationHistoryContextMenu(
                    historyType: .forward,
                    windowState: windowState
                )
            }

        }
    }

    private var sidebarToggleButton: some View {
        let sidebarOnLeft = nookSettings.sidebarPosition == .left

        return Button(
            "Toggle Sidebar",
            systemImage: sidebarOnLeft ? "sidebar.left" : "sidebar.right"
        ) {
            browserManager.toggleSidebar(for: windowState)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(NavButtonStyle())
        .foregroundStyle(navButtonColor)
        .animation(
            shouldAnimateColorChange ? .easeInOut(duration: 0.3) : nil,
            value: navButtonColor
        )
    }

    private var shouldShowWindowButtonsInTopBar: Bool {
        !windowState.isSidebarVisible && nookSettings.sidebarPosition == .left
    }

    private var urlBar: some View {
        let currentTab = browserManager.currentTab(for: windowState)

        return HStack(spacing: 8) {
            Image(systemName: currentTab == nil ? "magnifyingglass" : "globe")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(urlBarTextColor.opacity(0.8))

            if currentTab != nil {
                Text(displayURL)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(urlBarTextColor)
                    .tracking(-0.1)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            } else {
                EmptyView()
            }

            if currentTab != nil {
                URLBarActionButtons(
                    isHovering: isHovering,
                    foregroundColor: urlBarTextColor,
                    onCopy: {
                        browserManager.copyCurrentURL()
                    },
                    onRefresh: refreshCurrentTab
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(urlBarBackgroundColor)
        .animation(
            shouldAnimateColorChange ? .easeInOut(duration: 0.3) : nil,
            value: urlBarBackgroundColor
        )
        .clipShape(RoundedRectangle(cornerRadius: LexonTheme.pillCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LexonTheme.pillCornerRadius, style: .continuous)
                .stroke(LexonTheme.border(for: colorScheme), lineWidth: 0.5)
        }
        .onTapGesture {
            if let currentTab = browserManager.currentTab(for: windowState) {
                commandPalette.openWithCurrentURL(currentTab.url)
            } else {
                commandPalette.open()
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private func updateCurrentTab() {
        tabWrapper.updateTab(browserManager.currentTab(for: windowState))
    }

    private func goBack() {
        if let tab = tabWrapper.tab,
            let webView = browserManager.getWebView(
                for: tab.id,
                in: windowState.id
            )
        {
            webView.goBack()
        } else {
            tabWrapper.tab?.goBack()
        }
    }

    private func goForward() {
        if let tab = tabWrapper.tab,
            let webView = browserManager.getWebView(
                for: tab.id,
                in: windowState.id
            )
        {
            webView.goForward()
        } else {
            tabWrapper.tab?.goForward()
        }
    }

    private func refreshCurrentTab() {
        tabWrapper.tab?.refresh()
    }

    // Determine if we should animate color changes (within same tab) or snap (tab switch)
    private var shouldAnimateColorChange: Bool {
        let currentTabId = browserManager.currentTab(for: windowState)?.id
        return currentTabId == previousTabId
    }

    // Top bar background color - matches top-right pixel of webview
    private var topBarBackgroundColor: Color {
        LexonTheme.chromeFill(for: colorScheme)
    }

    // Nav button color - light on dark backgrounds, dark on light backgrounds
    private var navButtonColor: Color {
        LexonTheme.primaryText(for: colorScheme)
    }

    // URL bar background color - slightly adjusted for visual distinction
    private var urlBarBackgroundColor: Color {
        LexonTheme.fieldFill(for: colorScheme, isHovered: isHovering)
    }

    // Text color for URL bar - ensures proper contrast
    private var urlBarTextColor: Color {
        LexonTheme.secondaryText(for: colorScheme)
    }

    // Bottom border color - lighter when dark, darker when light
    private var bottomBorderColor: Color {
        LexonTheme.border(for: colorScheme)
    }

    // Helper to adjust color brightness
    private func adjustColorBrightness(_ color: Color, factor: CGFloat) -> Color
    {
        #if canImport(AppKit)
            guard let nsColor = NSColor(color).usingColorSpace(.sRGB) else {
                return color
            }
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            // Clamp values between 0 and 1
            r = min(1.0, max(0.0, r * factor))
            g = min(1.0, max(0.0, g * factor))
            b = min(1.0, max(0.0, b * factor))

            return Color(
                nsColor: NSColor(srgbRed: r, green: g, blue: b, alpha: a)
            )
        #else
            return color
        #endif
    }

    private var displayURL: AttributedString {
        guard let currentTab = browserManager.currentTab(for: windowState)
        else {
            return ""
        }

        return formatURL(
            currentTab.url,
            title: currentTab.name,
            isHovering: isHovering
        )
    }

    private func formatURL(_ url: URL, title: String?, isHovering: Bool)
        -> AttributedString
    {
        if isHovering {
            guard let host = url.host else {
                return AttributedString(url.absoluteString)
            }

            let cleanHost =
                host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

            let hostString = AttributedString(cleanHost)

            var pathString = AttributedString()

            if !url.path.isEmpty {
                pathString += AttributedString(url.path)
            }

            if let query = url.query {
                pathString += AttributedString("?" + query)
            }

            pathString.foregroundColor = urlBarTextColor.opacity(0.35)

            return hostString + pathString
        }

        guard let host = url.host else {
            return AttributedString(url.absoluteString)
        }

        let cleanHost =
            host.hasPrefix("www.") ? String(host.dropFirst(4)) : host

        if url.path.isEmpty || url.path == "/" {
            return AttributedString(cleanHost)
        } else {
            let displayTitle = title ?? cleanHost
            var result = AttributedString(cleanHost)
            var titlePart = AttributedString(" / " + displayTitle)
            titlePart.foregroundColor = urlBarTextColor.opacity(0.35)
            result.append(titlePart)
            return result
        }
    }

    private func pipButton(for tab: Tab) -> some View {
        Button(action: {
            tab.requestPictureInPicture()
        }) {
            Image(
                systemName: browserManager.currentTabHasPiPActive()
                    ? "pip.exit" : "pip.enter"
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(urlBarTextColor)
            .animation(
                shouldAnimateColorChange ? .easeInOut(duration: 0.3) : nil,
                value: urlBarTextColor
            )
            .frame(width: 16, height: 16)
            .contentShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BrowserUtilityButtonsView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    let navButtonColor: Color
    var spacesWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: 6) {
            historyButton
            downloadsButton
        }
    }

    private var historyButton: some View {
        BrowserUtilityPanelButton(
            title: "History",
            systemImage: "clock.arrow.circlepath",
            navButtonColor: navButtonColor,
            isActive: windowState.presentedUtilityPanel == .history
        ) {
            browserManager.toggleUtilityPanel(.history, for: windowState)
        }
    }

    private var downloadsButton: some View {
        BrowserUtilityPanelButton(
            title: "Downloads",
            systemImage: "arrow.down.circle",
            navButtonColor: navButtonColor,
            isActive: windowState.presentedUtilityPanel == .downloads
        ) {
            browserManager.toggleUtilityPanel(.downloads, for: windowState)
        }
        .overlay(alignment: .topTrailing) {
            DownloadIndicator()
                .environmentObject(browserManager)
                .offset(x: 6, y: -6)
        }
    }
}

struct BrowserUtilityPanelButton: View {
    let title: String
    let systemImage: String
    let navButtonColor: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BrowserUtilityPanelIcon(
                title: title,
                systemImage: systemImage,
                navButtonColor: navButtonColor,
                isActive: isActive
            )
        }
        .buttonStyle(.plain)
    }
}

struct BrowserUtilityPanelIcon: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false

    let title: String
    let systemImage: String
    let navButtonColor: Color
    let isActive: Bool

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(navButtonColor)
            .frame(width: 32, height: 32)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .help(title)
        .onHover { state in
            isHovered = state
        }
    }

    private var backgroundColor: Color {
        if isActive {
            return LexonTheme.activeFill(for: colorScheme)
        }

        return isHovered
            ? LexonTheme.hoverFill(for: colorScheme)
            : LexonTheme.fieldFill(for: colorScheme)
    }
}

struct BrowserUtilityPanelView: View {
    @EnvironmentObject private var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.colorScheme) private var colorScheme

    let panel: BrowserUtilityPanel

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            Group {
                switch panel {
                case .history:
                    SidebarMenuHistoryTab()
                        .environmentObject(browserManager)
                        .environmentObject(browserManager.gradientColorManager)
                case .downloads:
                    SidebarMenuDownloadsTab()
                        .environmentObject(browserManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: panel == .history ? 430 : 400, height: 520)
        .background(panelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LexonTheme.border(for: colorScheme), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: LexonTheme.shadow(for: colorScheme), radius: 24, x: 0, y: 16)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: panel == .history ? "clock.arrow.circlepath" : "arrow.down.circle")
                .font(.system(size: 13, weight: .semibold))
            Text(panel == .history ? "History" : "Downloads")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button("Close", systemImage: "xmark") {
                browserManager.dismissUtilityPanel(for: windowState)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(NavButtonStyle())
            .foregroundStyle(LexonTheme.primaryText(for: colorScheme))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LexonTheme.chromeFill(for: colorScheme))
        .foregroundStyle(LexonTheme.primaryText(for: colorScheme))
    }

    private var panelBackground: some View {
        ZStack {
            SpaceGradientBackgroundView()
                .environmentObject(browserManager)
                .environmentObject(browserManager.gradientColorManager)
                .environment(windowState)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LexonTheme.sidebarShell(for: colorScheme))
        }
    }
}

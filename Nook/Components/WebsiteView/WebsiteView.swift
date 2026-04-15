//
//  WebsiteView.swift
//  Nook
//
//  Created by Maciek Bagiński on 28/07/2025.
//

import SwiftUI
import WebKit
import AppKit

// MARK: - Status Bar View
struct LinkStatusBar: View {
    let hoveredLink: String?
    let isCommandPressed: Bool
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme
    @State private var shouldShow: Bool = false
    @State private var hoverTask: Task<Void, Never>?
    @State private var displayedLink: String? = nil
    
    var body: some View {
        // Show the view if we have a link to display (current or last shown)
        if let link = displayedLink, !link.isEmpty {
            Text(displayText(for: link))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textColor)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.ultraThickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 999))
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(borderColor, lineWidth: 1)
                )
                .opacity(shouldShow ? 1 : 0)
                .animation(.easeOut(duration: 0.25), value: shouldShow)
                .onChange(of: hoveredLink) {_,  newLink in
                    handleHoverChange(newLink: newLink)
                }
                .onAppear {
                    handleHoverChange(newLink: hoveredLink)
                }
                .onDisappear {
                    hoverTask?.cancel()
                    hoverTask = nil
                    shouldShow = false
                    displayedLink = nil
                }
        } else {
            Color.clear
                .onChange(of: hoveredLink) {_,  newLink in
                    handleHoverChange(newLink: newLink)
                }
        }
    }
    
    private func displayText(for link: String) -> String {
        let truncatedLink = truncateLink(link)
        if isCommandPressed {
            return "Open \(truncatedLink) in a new tab and focus it"
        } else {
            return truncatedLink
        }
    }
    
    private func handleHoverChange(newLink: String?) {
        // Cancel any existing task
        hoverTask?.cancel()
        hoverTask = nil
        
        if let link = newLink, !link.isEmpty {
            // New link - update displayed link immediately
            displayedLink = link
            
            // Wait then show if not already showing
            if !shouldShow {
                hoverTask = Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                    if !Task.isCancelled {
                        await MainActor.run { shouldShow = true }
                    }
                }
            }
        } else {
            // Link cleared - wait then hide
            hoverTask = Task {
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s delay
                if !Task.isCancelled {
                    await MainActor.run {
                        shouldShow = false
                    }
                    // Clear displayed link after fade out animation completes
                    try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s for fade out
                    if !Task.isCancelled {
                        await MainActor.run {
                            displayedLink = nil
                        }
                    }
                }
            }
        }
    }
    
    private func truncateLink(_ link: String) -> String {
        if link.count > 60 {
            let firstPart = String(link.prefix(30))
            let lastPart = String(link.suffix(30))
            return "\(firstPart)...\(lastPart)"
        }
        return link
    }
    
    private var backgroundColor: some View {
        Group {
            if colorScheme == .dark {
                // Dark mode: gradient background using accent color
                LinearGradient(
                    gradient: Gradient(colors: [
                        accentColor,
                        lighterAccentColor
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else {
                // Light mode: white background
                Color.white
            }
        }
    }
    
    private var lighterAccentColor: Color {
        #if os(macOS)
        // Blend the accent color with white for lighter variant
        let nsColor = NSColor(accentColor)
        if let blended = nsColor.blended(withFraction: 0.35, of: .white) {
            return Color(nsColor: blended)
        } else {
            return accentColor
        }
        #else
        return accentColor
        #endif
    }
    
    private var textColor: Color {
        if colorScheme == .dark {
            return Color.white
        } else {
            // Light mode: colored text using accent color
            return accentColor
        }
    }
    
    private var borderColor: Color {
        if colorScheme == .dark {
            return .white.opacity(0.2)
        } else {
            return accentColor.opacity(0.3)
        }
    }
}

struct WebsiteView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.nookSettings) var nookSettings
    @State private var hoveredLink: String?
    @State private var isCommandPressed: Bool = false

    private var cornerRadius: CGFloat {
        LexonTheme.controlCornerRadius
    }
    
    private var webViewClipShape: AnyShape {
        AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    var body: some View {
        ZStack() {
            Group {
                if browserManager.currentTab(for: windowState) != nil {
                    GeometryReader { _ in
                        TabCompositorWrapper(
                            browserManager: browserManager,
                            hoveredLink: $hoveredLink,
                            isCommandPressed: $isCommandPressed,
                            windowState: windowState
                        )
                        .background(Color(nsColor: .windowBackgroundColor))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(webViewClipShape)
                        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 0)
                        // Critical: Use allowsHitTesting to prevent SwiftUI from intercepting mouse events
                        // This allows right-clicks to pass through to the underlying NSView (WKWebView)
                        .allowsHitTesting(true)
                    }
                    // Removed SwiftUI contextMenu - it intercepts ALL right-clicks
                    // WKWebView's willOpenMenu will handle context menus for images
                } else {
                    EmptyWebsiteView()
                }
            }
            VStack {
                HStack {
                    Spacer()
                    Group {
                        if let assist = browserManager.oauthAssist,
                           browserManager.currentTab(for: windowState)?.id == assist.tabId {
                            OAuthAssistBanner(host: assist.host)
                                .environmentObject(browserManager)
                                .environment(windowState)
                                .padding(10)
                        }
                    }
                    // Animate toast insertions/removals
                    .animation(.smooth(duration: 0.25), value: browserManager.oauthAssist != nil)
                }
                Spacer()
                if nookSettings.showLinkStatusBar {
                    HStack {
                        LinkStatusBar(
                            hoveredLink: hoveredLink,
                            isCommandPressed: isCommandPressed,
                            accentColor: browserManager.gradientColorManager.primaryColor
                        )
                        .padding(10)
                        Spacer()
                    }
                }
                
            }
        }
    }

}

// MARK: - Tab Compositor Wrapper
struct TabCompositorWrapper: NSViewRepresentable {
    let browserManager: BrowserManager
    @Binding var hoveredLink: String?
    @Binding var isCommandPressed: Bool
    let windowState: BrowserWindowState

    class Coordinator {
        weak var browserManager: BrowserManager?
        let windowState: BrowserWindowState
        var lastCurrentId: UUID? = nil
        var lastSize: CGSize = .zero
        var lastVersion: Int = -1
        var frameObserver: NSObjectProtocol? = nil
        init(browserManager: BrowserManager?, windowState: BrowserWindowState) {
            self.browserManager = browserManager
            self.windowState = windowState
        }
        deinit {
            if let token = frameObserver {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(browserManager: browserManager, windowState: windowState) }

    func makeNSView(context: Context) -> NSView {
        let containerView = ContainerView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.postsFrameChangedNotifications = true

        // Store reference to container view in WebViewCoordinator
        browserManager.webViewCoordinator?.setCompositorContainerView(containerView, for: windowState.id)

        // Observe size changes to recompute pane layout when available width changes
        let coord = context.coordinator
        // MEMORY LEAK FIX: Capture coord weakly to break potential retain cycle
        // Coordinator → frameObserver token → closure → Coordinator
        coord.frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: containerView,
            queue: .main
        ) { [weak containerView, weak coord] _ in
            guard let cv = containerView else { return }
            // Rebuild compositor to anchor left/right panes to new bounds
            updateCompositor(cv)
            coord?.lastSize = cv.bounds.size
        }

        // Set up link hover callbacks for current tab
        if let currentTab = browserManager.currentTab(for: windowState) {
            setupHoverCallbacks(for: currentTab)
        }
        
        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Only rebuild compositor when meaningful inputs change
        let size = nsView.bounds.size
        let currentId = browserManager.currentTab(for: windowState)?.id
        let compositorVersion = windowState.compositorVersion
        let needsRebuild =
            context.coordinator.lastCurrentId != currentId ||
            context.coordinator.lastSize != size ||
            context.coordinator.lastVersion != compositorVersion

        if needsRebuild {
            let previousCurrentId = context.coordinator.lastCurrentId
            updateCompositor(nsView)
            context.coordinator.lastCurrentId = currentId
            context.coordinator.lastSize = size
            context.coordinator.lastVersion = compositorVersion

            // Restore focus when tab changed (webview is now in hierarchy)
            if previousCurrentId != currentId {
                DispatchQueue.main.async {
                    guard let window = nsView.window else { return }
                    for subview in nsView.subviews.reversed() {
                        if let webView = subview as? WKWebView, !webView.isHidden {
                            window.makeFirstResponder(webView)
                            return
                        }
                        for child in subview.subviews {
                            if let webView = child as? WKWebView, !child.isHidden {
                                window.makeFirstResponder(webView)
                                return
                            }
                        }
                    }
                }
            }
        }
        
        // Mark current tab as accessed (resets unload timer)
        if let currentTab = browserManager.currentTab(for: windowState) {
            browserManager.compositorManager.markTabAccessed(currentTab.id)
            setupHoverCallbacks(for: currentTab)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.browserManager?.webViewCoordinator?.removeCompositorContainerView(for: coordinator.windowState.id)
    }

    private func updateCompositor(_ containerView: NSView) {
        print("🔍 [MEMDEBUG] updateCompositor() CALLED - Window: \(windowState.id.uuidString.prefix(8)), Size: \(containerView.bounds.size)")
        let existingSubviews = containerView.subviews.count
        print("🔍 [MEMDEBUG]   Removing \(existingSubviews) existing subviews")
        containerView.subviews.forEach { $0.removeFromSuperview() }

        let allTabs = browserManager.tabsForDisplay(in: windowState)
        print("🔍 [MEMDEBUG]   Processing \(allTabs.count) tabs for display")
        for tab in allTabs {
            print("🔍 [MEMDEBUG]     Tab: \(tab.id.uuidString.prefix(8)), Name: \(tab.name), isUnloaded: \(tab.isUnloaded)")
        }

        let currentId = browserManager.currentTab(for: windowState)?.id
        for tab in allTabs where !tab.isUnloaded {
            let webView = webView(for: tab, windowId: windowState.id)
            webView.frame = containerView.bounds
            webView.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
            containerView.addSubview(webView)
            webView.isHidden = tab.id != currentId
        }

        // Log final state
        let webViewCount = containerView.subviews.filter { $0 is WKWebView }.count
        let totalSubviews = containerView.subviews.count
        print("🔍 [MEMDEBUG] updateCompositor() COMPLETE - Window: \(windowState.id.uuidString.prefix(8)), WebViews in container: \(webViewCount), Total subviews: \(totalSubviews)")
    }

    private func setupHoverCallbacks(for tab: Tab) {
        // Set up link hover callback
        tab.onLinkHover = { [self] href in
            DispatchQueue.main.async {
                self.hoveredLink = href
                if let href = href {
                    print("Hovering over link: \(href)")
                }
            }
        }
        
        // Set up command hover callback
        tab.onCommandHover = { [self] href in
            DispatchQueue.main.async {
                self.isCommandPressed = href != nil
            }
        }
    }

    private func webView(for tab: Tab, windowId: UUID) -> WKWebView {
        print("🔍 [MEMDEBUG] WebsiteView.webView() REQUESTED - Tab: \(tab.id.uuidString.prefix(8)), Name: \(tab.name), Window: \(windowId.uuidString.prefix(8))")
        print("🔍 [MEMDEBUG]   tab.isUnloaded: \(tab.isUnloaded), tab.assignedWebView exists: \(tab.assignedWebView != nil), primaryWindowId: \(tab.primaryWindowId?.uuidString.prefix(8) ?? "nil")")
        
        // Use the new smart WebView assignment system
        // This ensures only ONE WebView per tab in single-window mode
        if let coordinator = browserManager.webViewCoordinator {
            let webView = coordinator.getOrCreateWebView(for: tab, in: windowId, tabManager: browserManager.tabManager)
            print("🔍 [MEMDEBUG]   -> Got WebView via smart assignment: \(Unmanaged.passUnretained(webView).toOpaque())")
            return webView
        }
        
        // Fallback to old behavior (should never happen)
        print("⚠️ [MEMDEBUG] WARNING: No WebViewCoordinator found, using fallback!")
        return browserManager.createWebView(for: tab.id, in: windowId)
    }


}

// MARK: - Container View that forwards right-clicks to webviews

private class ContainerView: NSView {
    // Don't intercept events - let them pass through to webviews
    override var acceptsFirstResponder: Bool { false }

    override func resetCursorRects() {
        // Empty: prevents NSHostingView and other ancestors from registering
        // arrow cursor rects over the webview. WKWebView uses NSCursor.set()
        // internally, which works correctly when cursor rects don't override it.
    }

    // Forward right-clicks to the webview below so context menus work
    override func rightMouseDown(with event: NSEvent) {
        print("🔽 [ContainerView] rightMouseDown received, forwarding to webview")
        // Find the webview at this point and forward the event
        let point = convert(event.locationInWindow, from: nil)
        // Use hitTest to find the actual view at this point (will skip overlay if hitTest returns nil)
        if let hitView = hitTest(point) {
            if let webView = hitView as? WKWebView {
                print("🔽 [ContainerView] Found webview via hitTest, forwarding rightMouseDown")
                webView.rightMouseDown(with: event)
                return
            }
            // Check if hitView contains a webview
            if let webView = findWebView(in: hitView, at: point) {
                print("🔽 [ContainerView] Found nested webview, forwarding rightMouseDown")
                webView.rightMouseDown(with: event)
                return
            }
        }
        // Fallback: search all subviews
        for subview in subviews.reversed() {
            if let webView = findWebView(in: subview, at: point) {
                print("🔽 [ContainerView] Found webview in subviews, forwarding rightMouseDown")
                webView.rightMouseDown(with: event)
                return
            }
        }
        print("🔽 [ContainerView] No webview found, calling super")
        super.rightMouseDown(with: event)
    }
    
    private func findWebView(in view: NSView, at point: NSPoint) -> WKWebView? {
        let pointInView = view.convert(point, from: self)
        if view.bounds.contains(pointInView) {
            if let webView = view as? WKWebView {
                return webView
            }
            for subview in view.subviews {
                if let webView = findWebView(in: subview, at: point) {
                    return webView
                }
            }
        }
        return nil
    }
}


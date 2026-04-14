//
//  NavButtonsView.swift
//  Nook
//
//  Created by Maciek Bagiński on 30/07/2025.
//
import SwiftUI

// Wrapper to properly observe Tab object and use active window's WebView
@MainActor
class ObservableTabWrapper: ObservableObject {
    @Published var tab: Tab?
    weak var browserManager: BrowserManager?
    weak var windowState: BrowserWindowState?
    
    var canGoBack: Bool {
        if let tab = tab,
           let browserManager = browserManager,
           let windowState = windowState,
           let webView = browserManager.getWebView(for: tab.id, in: windowState.id) {
            return webView.canGoBack
        }
        return tab?.canGoBack ?? false
    }
    
    var canGoForward: Bool {
        if let tab = tab,
           let browserManager = browserManager,
           let windowState = windowState,
           let webView = browserManager.getWebView(for: tab.id, in: windowState.id) {
            return webView.canGoForward
        }
        return tab?.canGoForward ?? false
    }
    
    func updateTab(_ newTab: Tab?) {
        tab = newTab
    }
    
    func setContext(browserManager: BrowserManager, windowState: BrowserWindowState) {
        self.browserManager = browserManager
        self.windowState = windowState
    }
}

struct NavButtonsView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.nookSettings) var nookSettings
    var effectiveSidebarWidth: CGFloat?
    @StateObject private var tabWrapper = ObservableTabWrapper()
    @State private var isMenuHovered = false

    var body: some View {
        let sidebarOnLeft = nookSettings.sidebarPosition == .left
        let sidebarWidthForLayout = effectiveSidebarWidth ?? windowState.sidebarWidth

        let navigationCollapseThreshold: CGFloat = 250
        let refreshCollapseThreshold: CGFloat = 210

        let shouldCollapseNavigation = sidebarWidthForLayout < navigationCollapseThreshold
        let shouldCollapseRefresh = sidebarWidthForLayout < refreshCollapseThreshold
        
        HStack(spacing: 2) {
            if sidebarOnLeft {
                MacButtonsView()
                    .frame(width: 70)
            }
            
            Button("Toggle Sidebar", systemImage: sidebarOnLeft ? "sidebar.left" : "sidebar.right") {
                browserManager.toggleSidebar(for: windowState)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(NavButtonStyle())
            .foregroundStyle(Color.primary)
            
            Spacer()
            
            HStack(alignment: .center, spacing: 8) {
                if shouldCollapseNavigation {
                    collapsedMenu(
                        includeNavigation: true,
                        includeRefresh: shouldCollapseRefresh
                    )
                } else {
                    HStack(alignment: .center, spacing: 8) {
                        Button("Go Back", systemImage: "arrow.backward", action: goBack)
                            .labelStyle(.iconOnly)
                            .buttonStyle(NavButtonStyle())
                            .foregroundStyle(Color.primary)
                            .disabled(!tabWrapper.canGoBack)
                            .contextMenu {
                                NavigationHistoryContextMenu(
                                    historyType: .back,
                                    windowState: windowState
                                )
                            }
                        
                        Button("Go Forward", systemImage: "arrow.forward", action: goForward)
                            .labelStyle(.iconOnly)
                            .buttonStyle(NavButtonStyle())
                            .foregroundStyle(Color.primary)
                            .disabled(!tabWrapper.canGoForward)
                            .contextMenu {
                                NavigationHistoryContextMenu(
                                    historyType: .forward,
                                    windowState: windowState
                                )
                            }
                    }
                    
                    if shouldCollapseRefresh {
                        collapsedMenu(
                            includeNavigation: false,
                            includeRefresh: shouldCollapseRefresh
                        )
                    }
                }
                
                BrowserUtilityButtonsView(
                    navButtonColor: .primary,
                    spacesWidth: 72
                )
                .environmentObject(browserManager)
                .environment(windowState)
                
                if !sidebarOnLeft {
                    MacButtonsView()
                        .frame(width: 70)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            DoubleClickView {
                if let window = NSApp.keyWindow {
                    window.performZoom(nil)
                }
            }
        )
        .onAppear {
            tabWrapper.setContext(browserManager: browserManager, windowState: windowState)
            updateCurrentTab()
        }
        .onChange(of: browserManager.currentTab(for: windowState)?.id) { _, _ in
            updateCurrentTab()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            updateCurrentTab()
        }
    }
    
    private func updateCurrentTab() {
        tabWrapper.updateTab(browserManager.currentTab(for: windowState))
    }
    
    private func goBack() {
        if let tab = tabWrapper.tab,
           let webView = browserManager.getWebView(for: tab.id, in: windowState.id) {
            webView.goBack()
        } else {
            tabWrapper.tab?.goBack()
        }
    }
    
    private func goForward() {
        if let tab = tabWrapper.tab,
           let webView = browserManager.getWebView(for: tab.id, in: windowState.id) {
            webView.goForward()
        } else {
            tabWrapper.tab?.goForward()
        }
    }
    
    private func refreshCurrentTab() {
        tabWrapper.tab?.refresh()
    }
    
    @ViewBuilder
    private func collapsedMenu(includeNavigation: Bool, includeRefresh: Bool) -> some View {
        if includeNavigation || includeRefresh {
            Menu {
                if includeNavigation {
                    Button(action: goBack) {
                        Label("Go Back", systemImage: "arrow.backward")
                    }
                    .disabled(!tabWrapper.canGoBack)

                    Button(action: goForward) {
                        Label("Go Forward", systemImage: "arrow.forward")
                    }
                    .disabled(!tabWrapper.canGoForward)
                }

                if includeRefresh {
                    if includeNavigation {
                        Divider()
                    }
                    Button(action: refreshCurrentTab) {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                }
            } label: {
                Label("Navigation", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
            }
            .menuStyle(.button)
            .buttonStyle(NavButtonStyle())
        }
    }
}

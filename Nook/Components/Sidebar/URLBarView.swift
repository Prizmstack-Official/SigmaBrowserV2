//
//  URLBarView.swift
//  Nook
//
//  Created by Maciek Bagiński on 28/07/2025.
//

import SwiftUI

struct URLBarView: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.nookSettings) var nookSettings
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering: Bool = false
    var isSidebarHovered: Bool

    var body: some View {
        let currentTab = browserManager.currentTab(for: windowState)

        ZStack {
            HStack(spacing: 8) {
                Image(systemName: currentTab == nil ? "magnifyingglass" : "globe")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textColor)

                if currentTab != nil {
                    Text(displayURL)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("Search or ask a question...")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundStyle(textColor)
                }

                Spacer()

                if let currentTab {
                    URLBarActionButtons(
                        isHovering: isHovering,
                        foregroundColor: textColor,
                        onCopy: {
                            browserManager.copyCurrentURL()
                        },
                        onRefresh: {
                            currentTab.refresh()
                        }
                    )
                }

                if let currentTab,
                   (currentTab.hasVideoContent || currentTab.hasPiPActive) {
                    Button(action: {
                        currentTab.requestPictureInPicture()
                    }) {
                        Image(systemName: currentTab.hasPiPActive ? "pip.exit" : "pip.enter")
                            .font(.system(size: 12))
                            .foregroundStyle(textColor.opacity(currentTab.hasPiPActive ? 1.0 : 0.7))
                    }
                    .buttonStyle(.plain)
                    .help(currentTab.hasPiPActive ? "Exit Picture in Picture" : "Enter Picture in Picture")
                }

                if #available(macOS 15.5, *),
                   let extensionManager = browserManager.extensionManager {
                    ExtensionActionView(extensions: extensionManager.installedExtensions)
                        .environmentObject(browserManager)
                }
                }
                .padding(.leading, 12)
                .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
        .background(
           backgroundColor
        )
        .clipShape(RoundedRectangle(cornerRadius: LexonTheme.pillCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LexonTheme.pillCornerRadius, style: .continuous)
                .stroke(LexonTheme.border(for: colorScheme), lineWidth: 0.5)
        }
        // Report the frame in the window space so we can overlay the mini palette above all content
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: URLBarFramePreferenceKey.self,
                    value: proxy.frame(in: .named("WindowSpace"))
                )
            }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        // Focus URL bar when tapping anywhere in the bar
        .contentShape(Rectangle())
        .onTapGesture {
            let currentURL = browserManager.currentTab(for: windowState)?.url.absoluteString ?? ""
            windowState.commandPalette?.open(prefill: currentURL, navigateCurrentTab: true)
        }
        
    }
    
    private var backgroundColor: Color {
        LexonTheme.fieldFill(for: colorScheme, isHovered: isHovering)
    }
    private var textColor: Color {
        LexonTheme.secondaryText(for: colorScheme)
    }
    
    private var displayURL: String {
            guard let currentTab = browserManager.currentTab(for: windowState) else {
                return ""
            }
            return formatURL(currentTab.url)
        }
        
        private func formatURL(_ url: URL) -> String {
            guard let host = url.host else {
                return url.absoluteString
            }
            
            let cleanHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            
            return cleanHost
        }
}

// MARK: - URL Bar Button Style
struct URLBarButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isEnabled) var isEnabled
    @State private var isHovering: Bool = false
    
    private let cornerRadius: CGFloat = 12
    private let size: CGFloat = TopBarMetrics.controlSize
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor(isPressed: configuration.isPressed))
                .frame(width: size, height: size)
            
            configuration.label
                .foregroundStyle(colorScheme == .dark ? AppColors.iconActiveLight : AppColors.iconActiveDark)
        }
        .opacity(isEnabled ? 1.0 : 0.3)
        .contentTransition(.symbolEffect(.replace.upUp.byLayer, options: .nonRepeating))
        .scaleEffect(configuration.isPressed && isEnabled ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        if (isHovering || isPressed) && isEnabled {
            return isPressed
                ? LexonTheme.activeFill(for: colorScheme)
                : LexonTheme.hoverFill(for: colorScheme)
        }
        return Color.clear
    }
}

struct URLBarActionButtons: View {
    let isHovering: Bool
    let foregroundColor: Color
    let onCopy: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if isHovering {
                Button("Refresh Page", systemImage: "arrow.clockwise", action: onRefresh)
                    .labelStyle(.iconOnly)
                    .buttonStyle(URLBarButtonStyle())
                    .foregroundStyle(foregroundColor)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            CopyURLBarButton(
                foregroundColor: foregroundColor,
                onCopy: onCopy
            )
        }
    }
}

struct CopyURLBarButton: View {
    @State private var showCheckmark: Bool = false

    let foregroundColor: Color
    let onCopy: () -> Void

    var body: some View {
        Button(
            "Copy Link",
            systemImage: showCheckmark ? "checkmark" : "link"
        ) {
            onCopy()
            showCopiedState()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(URLBarButtonStyle())
        .foregroundStyle(foregroundColor)
        .contentTransition(.symbolEffect(.replace.upUp.byLayer, options: .nonRepeating))
    }

    private func showCopiedState() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showCheckmark = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCheckmark = false
            }
        }
    }
}

//
//  SpaceTab.swift
//  Nook
//
//  Created by Maciek Bagiński on 30/07/2025.
//

import SwiftUI

struct SpaceTab: View {
    @ObservedObject var tab: Tab
    var action: () -> Void
    var onDone: () -> Void
    var onToggleLock: () -> Void
    var onMute: () -> Void
    var nestingLevel: Int = 0
    @State private var isHovering: Bool = false
    @State private var isDoneHovering: Bool = false
    @State private var isLockHovering: Bool = false
    @State private var isSpeakerHovering: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            if isCurrentTab {
                print("🔄 [SpaceTab] Starting rename for tab '\(tab.name)' in window \(windowState.id)")
                tab.startRenaming()
                isTextFieldFocused = true
            } else {
                if tab.isRenaming {
                    tab.saveRename()
                }
                action()
            }
        }) {
            HStack(spacing: 10) {
                if nestingLevel > 0 {
                    Rectangle()
                        .fill(LexonTheme.border(for: colorScheme))
                        .frame(width: 12, height: 1)
                        .padding(.leading, CGFloat(nestingLevel - 1) * 14)
                }

                ZStack {
                    tab.favicon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .opacity(tab.isUnloaded ? 0.5 : 1.0)
                    
                    if tab.isUnloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .background(Color.gray)
                            .clipShape(Circle())
                            .offset(x: 6, y: -6)
                    }
                }
                if tab.hasAudioContent || tab.hasPlayingAudio || tab.isAudioMuted {
                    Button(action: {
                        onMute()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    isSpeakerHovering
                                        ? (isCurrentTab ? LexonTheme.activeFill(for: colorScheme) : LexonTheme.hoverFill(for: colorScheme))
                                        : Color.clear
                                )
                                .frame(width: 22, height: 22)
                                .animation(.easeInOut(duration: 0.05), value: isSpeakerHovering)
                            Image(systemName: tab.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .contentTransition(.symbolEffect(.replace))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(tab.isAudioMuted ? LexonTheme.secondaryText(for: colorScheme) : textTab)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        isSpeakerHovering = hovering
                    }
                    .help(tab.isAudioMuted ? "Unmute Audio" : "Mute Audio")
                }
                
                if tab.isRenaming {
                    TextField("", text: $tab.editingName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tab.isUnloaded ? LexonTheme.secondaryText(for: colorScheme) : textTab)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            tab.saveRename()
                        }
                        .onExitCommand {
                            tab.cancelRename()
                        }
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if let textField = NSApp.keyWindow?.firstResponder as? NSTextView {
                                    textField.selectAll(nil)
                                }
                            }
                        }
                        .focused($isTextFieldFocused)
                } else {
                    Text(tab.name)
                        .font(.system(size: 15, weight: isCurrentTab ? .semibold : .medium))
                        .foregroundStyle(textTab)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textSelection(.disabled) // Make text non-selectable
                }
                if tab.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if isHovering || tab.isLocked {
                    HStack(spacing: 4) {
                        Button(action: onToggleLock) {
                            Image(systemName: tab.isLocked ? "lock.fill" : "lock.open")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(textTab)
                                .frame(width: 24, height: 24)
                                .background(
                                    isLockHovering
                                        ? (isCurrentTab ? LexonTheme.activeFill(for: colorScheme) : LexonTheme.hoverFill(for: colorScheme))
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            isLockHovering = hovering
                        }

                        Button(action: onDone) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(tab.isLocked ? textTab.opacity(0.4) : textTab)
                                .frame(width: 24, height: 24)
                                .background(
                                    isDoneHovering
                                        ? (isCurrentTab ? LexonTheme.activeFill(for: colorScheme) : LexonTheme.hoverFill(for: colorScheme))
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .disabled(tab.isLocked)
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            isDoneHovering = hovering
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .frame(minWidth: 0, maxWidth: .infinity)
            .background(
                backgroundColor
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.05)) {
                isHovering = hovering
            }
        }
        .background(
            Group {
                if tab.isRenaming {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            tab.saveRename()
                        }
                }
            }
        )
        .contextMenu {
            Options()
        }
        .shadow(color: isActive ? shadowColor : Color.clear, radius: isActive ? 2 : 0, y: 1.5)
    }
    
    @ViewBuilder
    func Options() -> some View {
        Group {
            addToMenuSection
            Divider()
            editMenuSection
            Divider()
            actionsMenuSection
            Divider()
            closeMenuSection
        }
    }

    @ViewBuilder
    private var addToMenuSection: some View {
        let spaceId = tab.spaceId ?? UUID()
        let folders = browserManager.tabManager.folders(for: spaceId)

        Menu {
            ForEach(folders, id: \.id) { folder in
                Button {
                    // TODO: Add tab to folder
                } label: {
                    Label(folder.name, systemImage: "folder.fill")
                }
            }
        } label: {
            Label("Add to Folder", systemImage: "folder.badge.plus")
        }

        if !tab.isPinned && !tab.isSpacePinned {
            Button {
                browserManager.tabManager.pinTab(tab)
            } label: {
                Label("Add to Favorites", systemImage: "star.fill")
            }
        }
    }

    @ViewBuilder
    private var editMenuSection: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(tab.url.absoluteString, forType: .string)
        } label: {
            Label("Copy Link", systemImage: "link")
        }

        Button {
            // TODO: Implement share
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .disabled(true)

        Button {
            tab.startRenaming()
            isTextFieldFocused = true
        } label: {
            Label("Rename", systemImage: "character.cursor.ibeam")
        }
    }

    @ViewBuilder
    private var actionsMenuSection: some View {
        splitMenu
        duplicateButton
        moveToSpaceMenu
        Button {
            onToggleLock()
        } label: {
            Label(tab.isLocked ? "Unlock Tab" : "Lock Tab", systemImage: tab.isLocked ? "lock.open" : "lock.fill")
        }
    }

    @ViewBuilder
    private var splitMenu: some View {
        Menu {
            Button {
                browserManager.splitManager.enterSplit(with: tab, placeOn: .right, in: windowState)
            } label: {
                Label("Right", systemImage: "rectangle.righthalf.filled")
            }

            Button {
                browserManager.splitManager.enterSplit(with: tab, placeOn: .left, in: windowState)
            } label: {
                Label("Left", systemImage: "rectangle.lefthalf.filled")
            }
        } label: {
            Label("Open in Split", systemImage: "rectangle.split.2x1")
        }
    }

    @ViewBuilder
    private var duplicateButton: some View {
        Button {
            browserManager.duplicateCurrentTab()
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
    }

    @ViewBuilder
    private var moveToSpaceMenu: some View {
        let spaces = browserManager.tabManager.spaces
        Menu {
            ForEach(spaces, id: \.id) { space in
                Button {
                    browserManager.tabManager.moveTab(tab.id, to: space.id)
                } label: {
                    spaceLabel(for: space)
                }
                .disabled(space.id == tab.spaceId)
            }
        } label: {
            Label("Move to Space", systemImage: "square.grid.2x2")
        }
    }

    @ViewBuilder
    private func spaceLabel(for space: Space) -> some View {
        if space.icon.unicodeScalars.first?.properties.isEmoji == true {
            Label {
                Text(space.name)
            } icon: {
                Text(space.icon)
            }
        } else {
            Label(space.name, systemImage: space.icon)
        }
    }

    @ViewBuilder
    private var closeMenuSection: some View {
        if !tab.isPinned && !tab.isSpacePinned && tab.spaceId != nil {
            Button {
                browserManager.tabManager.closeAllTabsBelow(tab)
            } label: {
                Label("Mark All Below Done", systemImage: "arrow.down.to.line")
            }
        }

        Button {
            // TODO: Implement close all except this
        } label: {
            Label("Mark Others Done", systemImage: "checkmark.circle")
        }
        .disabled(true)

        Button(role: .destructive) {
            onDone()
        } label: {
            Label("Mark Done", systemImage: "checkmark")
        }
        .disabled(tab.isLocked)
    }

    private var isActive: Bool {
        return browserManager.currentTab(for: windowState)?.id == tab.id
    }
    
    private var isCurrentTab: Bool {
        return browserManager.currentTab(for: windowState)?.id == tab.id
    }
    private var shadowColor: Color {
        return colorScheme == .dark ? Color.clear : Color.black.opacity(0.08)
    }

    private var backgroundColor: Color {
        if isCurrentTab {
            return activeSpaceColor.opacity(colorScheme == .dark ? 0.78 : 0.18)
        } else if isHovering {
            return LexonTheme.hoverFill(for: colorScheme)
        } else {
            return Color.clear
        }
    }
    private var textTab: Color {
        isCurrentTab
            ? LexonTheme.primaryText(for: colorScheme)
            : LexonTheme.secondaryText(for: colorScheme)
    }

    private var activeSpaceColor: Color {
        if let currentSpace = windowState.currentSpace, currentSpace.id == tab.spaceId {
            return Color(nsColor: currentSpace.color)
        }

        if windowState.isIncognito,
           let space = windowState.ephemeralSpaces.first(where: { $0.id == tab.spaceId }) {
            return Color(nsColor: space.color)
        }

        if let space = browserManager.tabManager.spaces.first(where: { $0.id == tab.spaceId }) {
            return Color(nsColor: space.color)
        }

        return LexonTheme.activeFill(for: colorScheme)
    }

}

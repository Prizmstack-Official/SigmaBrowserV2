//
//  SpacesListItem.swift
//  Nook
//
//  Created by Maciek Bagiński on 04/08/2025.
//  Refactored by Aether on 15/11/2025.
//

import SwiftUI

struct SpacesListItem: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(\.colorScheme) private var colorScheme

    let space: Space
    let isActive: Bool
    let compact: Bool
    let isFaded: Bool
    let buttonSideLength: CGFloat
    let onHoverChange: ((Bool) -> Void)?

    @State private var isHovering: Bool = false
    @StateObject private var emojiManager = EmojiPickerManager()

    private let dotSize: CGFloat = 6

    init(
        space: Space,
        isActive: Bool,
        compact: Bool,
        isFaded: Bool,
        buttonSideLength: CGFloat = 40,
        onHoverChange: ((Bool) -> Void)? = nil
    ) {
        self.space = space
        self.isActive = isActive
        self.compact = compact
        self.isFaded = isFaded
        self.buttonSideLength = buttonSideLength
        self.onHoverChange = onHoverChange
    }

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.1)) {
                browserManager.setActiveSpace(space, in: windowState)
            }
        } label: {
            spaceIcon
                .opacity(isActive ? 1.0 : 0.7)
                .frame(width: buttonSideLength, height: buttonSideLength)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(
            SpaceListItemButtonStyle(
                isActive: isActive,
                sideLength: buttonSideLength
            )
        )
        .layoutPriority(2)
        .foregroundStyle(LexonTheme.primaryText(for: colorScheme))
        .layoutPriority(isActive ? 1 : 0)
        .opacity(isFaded ? 0.3 : 1.0)
        .help(space.name)
        .onHover { hovering in
            isHovering = hovering
            onHoverChange?(hovering)
        }
        .contextMenu {
            spaceContextMenu
                .environmentObject(browserManager)
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private var spaceIcon: some View {
        if compact && !isActive {
            // Compact mode: show dot
            Circle()
                .fill(iconColor)
                .frame(width: dotSize, height: dotSize)
        } else {
            // Normal mode: show icon or emoji
            if isEmoji(space.icon) {
                Text(space.icon)
                    .font(.system(size: isActive ? 20 : 18))
                    .opacity(isActive ? 1.0 : 0.78)
                    .background(EmojiPickerAnchor(manager: emojiManager))
                    .onChange(of: emojiManager.selectedEmoji) { _, newValue in
                        space.icon = newValue
                        browserManager.tabManager.persistSnapshot()
                    }

            } else {
                Image(systemName: space.icon)
                    .font(.system(size: isActive ? 15 : 14, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(iconColor)
                    .background(EmojiPickerAnchor(manager: emojiManager))
                    .onChange(of: emojiManager.selectedEmoji) { _, newValue in
                        space.icon = newValue
                        browserManager.tabManager.persistSnapshot()
                    }
            }
        }
    }

    private var iconColor: Color {
        isActive
            ? LexonTheme.primaryText(for: colorScheme)
            : LexonTheme.tertiaryText(for: colorScheme)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var spaceContextMenu: some View {
        SpaceContextMenu(
            space: space,
            canDelete: canDeleteSpace,
            onEditName: showRenameDialog,
            onEditIcon: {
                showSpaceEditDialog(mode: .icon)
            },
            onOpenSettings: {
                showSpaceEditDialog(mode: .icon)
            },
            onDeleteSpace: {
                browserManager.tabManager.removeSpace(space.id)
            }
        )
    }

    // MARK: - Helper Methods

    private func showRenameDialog() {
        browserManager.dialogManager.showDialog(
            SpaceEditDialog(
                space: space,
                mode: .rename,
                onSave: { draft in
                    browserManager.tabManager.updateSpaceSettings(spaceId: space.id, using: draft)
                    browserManager.dialogManager.closeDialog()
                },
                onCancel: {
                    browserManager.dialogManager.closeDialog()
                }
            )
        )
    }

    private func showSpaceEditDialog(mode: SpaceEditDialog.Mode = .icon) {
        browserManager.dialogManager.showDialog(
            SpaceEditDialog(
                space: space,
                mode: mode,
                onSave: { draft in
                    browserManager.tabManager.updateSpaceSettings(spaceId: space.id, using: draft)
                    browserManager.dialogManager.closeDialog()
                },
                onCancel: {
                    browserManager.dialogManager.closeDialog()
                }
            )
        )
    }

    private var canDeleteSpace: Bool {
        browserManager.tabManager.spaces.count > 1
    }

    private func isEmoji(_ string: String) -> Bool {
        string.unicodeScalars.contains { scalar in
            (scalar.value >= 0x1F300 && scalar.value <= 0x1F9FF) // Emoticons & pictographs
                || (scalar.value >= 0x2600 && scalar.value <= 0x26FF) // Miscellaneous symbols
                || (scalar.value >= 0x2700 && scalar.value <= 0x27BF) // Dingbats
        }
    }
}

struct SpaceListItemButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isEnabled) var isEnabled
    @State private var isHovering: Bool = false
    let isActive: Bool
    let sideLength: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(backgroundColor(isPressed: configuration.isPressed))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: isActive ? 1 : 0.5)
                }

            configuration.label
                .foregroundStyle(.primary)
        }
        .frame(width: sideLength, height: sideLength)
        .opacity(isEnabled ? 1.0 : 0.3)
        
        .contentTransition(.symbolEffect(.replace.upUp.byLayer, options: .nonRepeating))
        .scaleEffect(configuration.isPressed && isEnabled ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
//    private var iconSize: CGFloat {
//        switch controlSize {
//        case .mini: 12
//        case .small: 14
//        case .regular: 16
//        case .large: 18
//        case .extraLarge: 20
//        @unknown default: 16
//        }
//    }
    
    private var cornerRadius: CGFloat {
        LexonTheme.controlCornerRadius
    }
    
    private var borderColor: Color {
        Color.clear
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard (isHovering || isPressed) && isEnabled else { return Color.clear }
        return isPressed
            ? LexonTheme.activeFill(for: colorScheme)
            : LexonTheme.hoverFill(for: colorScheme).opacity(0.75)
    }
}

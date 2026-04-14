import SwiftUI

struct SpaceTitle: View {
    @EnvironmentObject var browserManager: BrowserManager
    @Environment(\.colorScheme) var colorScheme

    let space: Space
    var iconSize: CGFloat = 16

    @State private var isHovering: Bool = false
    @State private var isRenaming: Bool = false
    @State private var draftName: String = ""
    @State private var selectedEmoji: String = ""
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var emojiFieldFocused: Bool
    @State private var isEllipsisHovering: Bool = false
    @ObservedObject private var dragSession = NookDragSessionManager.shared
    
    @StateObject private var emojiManager = EmojiPickerManager()

    var body: some View {
        HStack(spacing: 10) {
            titleAccessory

            if isRenaming {
                TextField("", text: $draftName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(textColor)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                    .focused($nameFieldFocused)
                    .onAppear {
                        draftName = space.name
                        DispatchQueue.main.async {
                            nameFieldFocused = true
                        }
                    }
                    .onSubmit {
                        commitRename()
                    }
                    .onExitCommand {
                        cancelRename()
                    }
            } else {
                Text(space.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture(count: 2) {
                        startRenaming()
                    }
            }

            Spacer()

            Menu {
                SpaceContextMenu(
                    space: space,
                    canDelete: canDeleteSpace,
                    onEditName: {
                        startRenaming()
                    },
                    onEditIcon: {
                        emojiManager.toggle()
                    },
                    onOpenSettings: {
                        browserManager.dialogManager.showDialog(
                            SpaceEditDialog(
                                space: space,
                                mode: .icon,
                                onSave: { draft in
                                    updateSpace(using: draft)
                                },
                                onCancel: {
                                    browserManager.dialogManager.closeDialog()
                                }
                            )
                        )
                    },
                    onDeleteSpace: deleteSpace
                )
                .environmentObject(browserManager)
                .environment(\.controlSize, .regular)
            } label: {
                Label("Configure Space", systemImage: "ellipsis")
                    .font(.body.weight(.semibold))
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.button)
            .buttonStyle(NavButtonStyle(size: .small))
            .foregroundStyle(LexonTheme.tertiaryText(for: colorScheme))
            .opacity(isHovering ? 0.9 : 0.0)

        }
        // Match tabs' internal left/right padding so text aligns
        .onChange(of: dragSession.pendingDrop) { _, drop in
            guard let drop = drop, drop.targetZone == .spacePinned(space.id) else { return }
            guard browserManager.tabManager.spacePinnedTabs(for: space.id).isEmpty else { return }
            let allTabs = browserManager.tabManager.allTabs()
            guard let tab = allTabs.first(where: { $0.id == drop.item.tabId }) else { return }
            let op = dragSession.makeDragOperation(from: drop, tab: tab)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                browserManager.tabManager.handleDragOperation(op)
            }
            dragSession.pendingDrop = nil
        }
        .padding(.leading, 4)
        .padding(.trailing, 2)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(hoverColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
        .onChange(of: nameFieldFocused) { _, focused in
            // When losing focus during rename, commit
            if isRenaming && !focused {
                commitRename()
            }
        }
        // Provide a right-click context menu
        .contextMenu {
            SpaceContextMenu(
                space: space,
                canDelete: canDeleteSpace,
                onEditName: {
                    startRenaming()
                },
                onEditIcon: {
                    emojiManager.toggle()
                },
                onOpenSettings: {
                    browserManager.dialogManager.showDialog(
                        SpaceEditDialog(
                            space: space,
                            mode: .icon,
                            onSave: { draft in
                                updateSpace(using: draft)
                            },
                            onCancel: {
                                browserManager.dialogManager.closeDialog()
                            }
                        )
                    )
                },
                onDeleteSpace: deleteSpace
            )
            .environmentObject(browserManager)
        }
    }
    
    //MARK: - Colors
    
    private var isDropHovering: Bool {
        guard dragSession.isDragging else { return false }
        return dragSession.activeZone == .spacePinned(space.id)
            && browserManager.tabManager.spacePinnedTabs(for: space.id).isEmpty
    }

    private var hoverColor: Color {
        isDropHovering ? LexonTheme.hoverFill(for: colorScheme) : .clear
    }
    private var textColor: Color {
        LexonTheme.primaryText(for: colorScheme)
    }

    @ViewBuilder
    private var titleAccessory: some View {
        ZStack {
            // Hidden field still allows emoji replacement without changing the visible title layout.
            TextField("", text: $selectedEmoji)
                .frame(width: 0, height: 0)
                .opacity(0)
                .focused($emojiFieldFocused)
                .onChange(of: selectedEmoji) { _, newValue in
                    if !newValue.isEmpty {
                        guard let lastChar = newValue.last else { return }
                        space.icon = String(lastChar)
                        browserManager.tabManager.persistSnapshot()
                        selectedEmoji = ""
                    }
                }

            Group {
                if isEmoji(space.icon) {
                    Text(space.icon)
                        .font(.system(size: iconSize))
                } else {
                    Image(systemName: space.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LexonTheme.secondaryText(for: colorScheme))
                }
            }
            .background(EmojiPickerAnchor(manager: emojiManager))
            .onTapGesture(count: 2) {
                emojiManager.toggle()
            }
            .onChange(of: emojiManager.selectedEmoji) { _, newValue in
                guard !newValue.isEmpty else { return }
                space.icon = newValue
                browserManager.tabManager.persistSnapshot()
            }
        }
    }

    private var canDeleteSpace: Bool {
        browserManager.tabManager.spaces.count > 1
    }

    // MARK: - Actions

    private func startRenaming() {
        draftName = space.name
        isRenaming = true
    }

    private func cancelRename() {
        isRenaming = false
        draftName = space.name
        nameFieldFocused = false
    }

    private func commitRename() {
        let newName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newName.isEmpty, newName != space.name {
            do {
                try browserManager.tabManager.renameSpace(
                    spaceId: space.id,
                    newName: newName
                )
            } catch {
                print("⚠️ Failed to rename space \(space.id.uuidString):", error)
            }
        }
        isRenaming = false
        nameFieldFocused = false
    }

    private func deleteSpace() {
        browserManager.tabManager.removeSpace(space.id)
    }

    private func createFolder() {
        print("🎯 SpaceTitle.createFolder() called for space '\(space.name)' (id: \(space.id.uuidString.prefix(8))...)")
        browserManager.tabManager.createFolder(for: space.id)
    }

    private func assignProfile(_ id: UUID) {
        browserManager.tabManager.assign(spaceId: space.id, toProfile: id)
    }

    private func updateSpace(using draft: SpaceSettingsDraft) {
        browserManager.tabManager.updateSpaceSettings(spaceId: space.id, using: draft)
        browserManager.dialogManager.closeDialog()
    }

    private func resolvedProfileName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return browserManager.profileManager.profiles.first(where: { $0.id == id })?.name
    }
    
    private func isEmoji(_ string: String) -> Bool {
        return string.unicodeScalars.contains { scalar in
            (scalar.value >= 0x1F300 && scalar.value <= 0x1F9FF) ||
            (scalar.value >= 0x2600 && scalar.value <= 0x26FF) ||
            (scalar.value >= 0x2700 && scalar.value <= 0x27BF)
        }
    }
}

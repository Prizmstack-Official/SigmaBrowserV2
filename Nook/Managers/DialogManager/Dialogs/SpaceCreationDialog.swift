//
//  SpaceCreationDialog.swift
//  Nook
//
//  Created by Maciek Bagiński on 04/08/2025.
//

import AppKit
import SwiftUI

struct SpaceCreationDialog: DialogPresentable {
    @State private var spaceName: String
    @State private var spaceIcon: String
    @State private var selectedProfileId: UUID?
    @State private var usesSeparateProfile: Bool
    @State private var isWorkspaceIncognito: Bool

    let onCreate: (SpaceSettingsDraft) -> Void
    let onCancel: () -> Void

    init(
        onCreate: @escaping (SpaceSettingsDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _spaceName = State(initialValue: "")
        _spaceIcon = State(initialValue: "")
        _selectedProfileId = State(initialValue: nil)
        _usesSeparateProfile = State(initialValue: false)
        _isWorkspaceIncognito = State(initialValue: false)
        self.onCreate = onCreate
        self.onCancel = onCancel
    }

    func dialogHeader() -> DialogHeader {
        DialogHeader(
            icon: "folder.badge.plus",
            title: "Create a New Space",
            subtitle: "Organize your tabs into a new space"
        )
    }

    @ViewBuilder
    func dialogContent() -> some View {
        SpaceCreationContent(
            spaceName: $spaceName,
            spaceIcon: $spaceIcon,
            selectedProfileId: $selectedProfileId,
            usesSeparateProfile: $usesSeparateProfile,
            isWorkspaceIncognito: $isWorkspaceIncognito
        )
    }

    func dialogFooter() -> DialogFooter {
        DialogFooter(
            rightButtons: [
                DialogButton(
                    text: "Cancel",
                    variant: .secondary,
                    keyboardShortcut: .escape,
                    action: onCancel
                ),
                DialogButton(
                    text: "Create Space",
                    iconName: "plus",
                    variant: .primary,
                    keyboardShortcut: .return,
                    action: handleCreate
                )
            ]
        )
    }

    private func handleCreate() {
        let trimmedName = spaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "New Space" : trimmedName
        let finalIcon = spaceIcon.isEmpty ? "✨" : spaceIcon
        let draft = SpaceSettingsDraft(
            name: finalName,
            icon: finalIcon,
            profileId: selectedProfileId,
            usesSeparateProfile: usesSeparateProfile,
            isWorkspaceIncognito: isWorkspaceIncognito
        )
        onCreate(draft)
    }
}

struct SpaceCreationContent: View {
    @Binding var spaceName: String
    @Binding var spaceIcon: String
    @Binding var selectedProfileId: UUID?
    @Binding var usesSeparateProfile: Bool
    @Binding var isWorkspaceIncognito: Bool
    @StateObject private var emojiManager = EmojiPickerManager()
    @EnvironmentObject var browserManager: BrowserManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Space Name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                NookTextField(
                    text: $spaceName,
                    placeholder: "Enter space name",
                    variant: .default,
                    iconName: "textformat"
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Space Icon")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    Button {
                        emojiManager.toggle()
                    } label: {
                        Text(
                            emojiManager.selectedEmoji.isEmpty
                                ? "✨" : emojiManager.selectedEmoji
                        )
                        .font(.system(size: 14))
                        .frame(width: 20, height: 20)
                        .padding(4)
                        .background(.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                    .background(EmojiPickerAnchor(manager: emojiManager))
                    .buttonStyle(PlainButtonStyle())

                    Text("Choose an emoji to represent this space")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Shared Profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Picker(
                    currentProfileName,
                    systemImage: currentProfileIcon,
                    selection: Binding(
                        get: {
                            selectedProfileId ?? browserManager.profileManager.profiles.first?.id ?? UUID()
                        },
                        set: { newId in
                            selectedProfileId = newId
                        }
                    )
                ) {
                    ForEach(browserManager.profileManager.profiles, id: \.id) { profile in
                        Label(profile.name, systemImage: profile.icon).tag(profile.id)
                    }
                }
                .disabled(usesSeparateProfile || isWorkspaceIncognito)

                Text(profileFootnote)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Preferences")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                SpaceSettingsToggleRow(
                    title: "Separate Profiles",
                    helpText: "Auto-create an isolated profile for this workspace when it is saved."
                ) {
                    Toggle("", isOn: $usesSeparateProfile)
                        .labelsHidden()
                }

                SpaceSettingsToggleRow(
                    title: "Incognito",
                    helpText: "Keep this workspace private with a non-persistent profile."
                ) {
                    Toggle("", isOn: $isWorkspaceIncognito)
                        .labelsHidden()
                }
            }
        }
        .padding(.horizontal, 4)
        .onAppear {
            if !spaceIcon.isEmpty {
                emojiManager.selectedEmoji = spaceIcon
            }
        }
        .onChange(of: emojiManager.selectedEmoji) { _, newValue in
            spaceIcon = newValue
        }
    }

    private var profileFootnote: String {
        if isWorkspaceIncognito {
            return "This workspace will open with a private session."
        }
        if usesSeparateProfile {
            return "A dedicated profile will be created automatically for this workspace."
        }
        return "Choose the shared profile this workspace should start with."
    }

    private var currentProfileName: String {
        guard let profileId = selectedProfileId,
              let profile = browserManager.profileManager.profiles.first(where: { $0.id == profileId })
        else {
            return browserManager.profileManager.profiles.first?.name ?? "Default"
        }
        return profile.name
    }

    private var currentProfileIcon: String {
        guard let profileId = selectedProfileId,
              let profile = browserManager.profileManager.profiles.first(where: { $0.id == profileId })
        else {
            return browserManager.profileManager.profiles.first?.icon ?? "person.circle"
        }
        return profile.icon
    }
}


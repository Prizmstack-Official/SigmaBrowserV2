//
//  SpaceEditDialog.swift
//  Nook
//
//  Created by OpenAI Codex on 22/01/2025.
//

import AppKit
import SwiftUI

struct SpaceEditDialog: DialogPresentable {
    enum Mode {
        case rename
        case icon
    }

    private let mode: Mode
    private let originalSpaceName: String
    private let originalSpaceIcon: String
    private let originalProfileId: UUID?
    private let originalUsesSeparateProfile: Bool
    private let originalWorkspaceIncognito: Bool

    @State private var spaceName: String
    @State private var spaceIcon: String
    @State private var selectedProfileId: UUID?
    @State private var usesSeparateProfile: Bool
    @State private var isWorkspaceIncognito: Bool

    private let onSaveChanges: (SpaceSettingsDraft) -> Void
    private let onCancelChanges: () -> Void

    init(
        space: Space,
        mode: Mode,
        onSave: @escaping (SpaceSettingsDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        let name = MainActor.assumeIsolated { space.name }
        let icon = MainActor.assumeIsolated { space.icon }
        let profileId = MainActor.assumeIsolated { space.profileId }
        let usesSeparateProfile = MainActor.assumeIsolated { space.usesSeparateProfile }
        let isWorkspaceIncognito = MainActor.assumeIsolated { space.isWorkspaceIncognito }
        self.mode = mode
        self.originalSpaceName = name
        self.originalSpaceIcon = icon
        self.originalProfileId = profileId
        self.originalUsesSeparateProfile = usesSeparateProfile
        self.originalWorkspaceIncognito = isWorkspaceIncognito
        _spaceName = State(initialValue: name)
        _spaceIcon = State(initialValue: icon)
        _selectedProfileId = State(initialValue: profileId)
        _usesSeparateProfile = State(initialValue: usesSeparateProfile)
        _isWorkspaceIncognito = State(initialValue: isWorkspaceIncognito)
        self.onSaveChanges = onSave
        self.onCancelChanges = onCancel
    }

    func dialogHeader() -> DialogHeader {
        DialogHeader(
            icon: "GEAR",
            title: "Space Settings",
            subtitle: originalSpaceName
        )
    }

    @ViewBuilder
    func dialogContent() -> some View {
        SpaceEditContent(
            spaceName: $spaceName,
            spaceIcon: $spaceIcon,
            selectedProfileId: $selectedProfileId,
            usesSeparateProfile: $usesSeparateProfile,
            isWorkspaceIncognito: $isWorkspaceIncognito,
            originalIcon: originalSpaceIcon,
            mode: mode
        )
    }

    func dialogFooter() -> DialogFooter {
        let trimmed = spaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveName = trimmed.isEmpty ? originalSpaceName : trimmed
        let iconValue = spaceIcon.isEmpty ? originalSpaceIcon : spaceIcon
        let sharedProfileId = selectedProfileId ?? originalProfileId
        let draft = SpaceSettingsDraft(
            name: effectiveName,
            icon: iconValue,
            profileId: sharedProfileId,
            usesSeparateProfile: usesSeparateProfile,
            isWorkspaceIncognito: isWorkspaceIncognito
        )

        return DialogFooter(
            rightButtons: [
                DialogButton(
                    text: "Cancel",
                    variant: .secondary,
                    action: onCancelChanges
                ),
                DialogButton(
                    text: "Save Changes",
                    iconName: "checkmark",
                    variant: .primary,
                    action: {
                        onSaveChanges(draft)
                    }
                )
            ]
        )
    }
}

private struct SpaceEditContent: View {
    @Binding var spaceName: String
    @Binding var spaceIcon: String
    @Binding var selectedProfileId: UUID?
    @Binding var usesSeparateProfile: Bool
    @Binding var isWorkspaceIncognito: Bool

    let originalIcon: String
    let mode: SpaceEditDialog.Mode

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
                        SpaceIconView(icon: currentIcon)
                            .frame(width: 28, height: 28)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                    .background(EmojiPickerAnchor(manager: emojiManager))
                    .buttonStyle(PlainButtonStyle())

                    Text("Choose an emoji or symbol to represent this space")
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
                    helpText: "Login to multiple accounts by isolating cookies and site data to this workspace."
                ) {
                    Toggle("", isOn: $usesSeparateProfile)
                        .labelsHidden()
                }

                SpaceSettingsToggleRow(
                    title: "Incognito",
                    helpText: "History won't be saved, and cookies will be deleted for this workspace's private profile."
                ) {
                    Toggle("", isOn: $isWorkspaceIncognito)
                        .labelsHidden()
                }

                SpaceSettingsToggleRow(
                    title: "Co-browsing",
                    helpText: "Co-browsing is not available yet."
                ) {
                    Toggle("", isOn: .constant(false))
                        .labelsHidden()
                        .disabled(true)
                }
            }
        }
        .padding(.horizontal, 4)
        .onAppear {
            if !spaceIcon.isEmpty {
                emojiManager.selectedEmoji = spaceIcon
            } else {
                emojiManager.selectedEmoji = originalIcon
            }
        }
        .onChange(of: emojiManager.selectedEmoji) { _, newValue in
            if !newValue.isEmpty {
                spaceIcon = newValue
            }
        }
    }

    private var profileFootnote: String {
        if isWorkspaceIncognito {
            return "This workspace uses a private session. Shared profile selection is restored when incognito is turned off."
        }
        if usesSeparateProfile {
            return "Saving will auto-create and assign a dedicated profile for this workspace."
        }
        return "Choose which shared profile this workspace should use."
    }

    private var currentIcon: String {
        if !spaceIcon.isEmpty {
            return spaceIcon
        }
        return originalIcon
    }

    private var currentProfileName: String {
        guard let profileId = selectedProfileId,
              let profile = browserManager.profileManager.profile(for: profileId)
        else {
            return browserManager.profileManager.profiles.first?.name ?? "Default"
        }
        return profile.name
    }

    private var currentProfileIcon: String {
        guard let profileId = selectedProfileId,
              let profile = browserManager.profileManager.profile(for: profileId)
        else {
            return browserManager.profileManager.profiles.first?.icon ?? "person.circle"
        }
        return profile.icon
    }
}

struct SpaceSettingsToggleRow<Control: View>: View {
    let title: String
    let helpText: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .help(helpText)
            }
            Spacer()
            control()
        }
    }
}

private struct SpaceIconView: View {
    let icon: String

    var body: some View {
        Group {
            if isEmoji(icon) {
                Text(icon)
                    .font(.system(size: 18))
            } else {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
            }
        }
        .frame(width: 20, height: 20)
    }

    private func isEmoji(_ string: String) -> Bool {
        return string.unicodeScalars.contains { scalar in
            (scalar.value >= 0x1F300 && scalar.value <= 0x1F9FF)
                || (scalar.value >= 0x2600 && scalar.value <= 0x26FF)
                || (scalar.value >= 0x2700 && scalar.value <= 0x27BF)
        }
    }
}


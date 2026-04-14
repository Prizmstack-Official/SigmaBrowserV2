//
//  WorkspaceCleanupDialog.swift
//  Nook
//
//  Confirmation dialog for workspace cleanup.
//

import SwiftUI

struct WorkspaceCleanupDialog: DialogPresentable {
    let workspaceName: String
    let workspaceIcon: String
    let candidateCount: Int
    let lockedCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    func dialogHeader() -> DialogHeader {
        DialogHeader(
            icon: "sparkles",
            title: "Clean Up Workspace",
            subtitle: "Only unlocked tabs in this workspace will be marked done"
        )
    }

    @ViewBuilder
    func dialogContent() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if workspaceIcon.unicodeScalars.first?.properties.isEmoji == true {
                    Text(workspaceIcon)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: workspaceIcon)
                        .font(.system(size: 18, weight: .semibold))
                }

                Text(workspaceName)
                    .font(.system(size: 16, weight: .semibold))
            }

            HStack(spacing: 8) {
                Label("\(candidateCount) tabs ready to clean", systemImage: "checkmark.circle")
                if lockedCount > 0 {
                    Label("\(lockedCount) locked", systemImage: "lock.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 6) {
                Label("Unlocked tabs will be marked done and removed from the active list.", systemImage: "sparkles")
                    .font(.caption)
                if lockedCount > 0 {
                    Label("Locked tabs stay exactly where they are.", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
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
                    text: "Clean Up",
                    iconName: "return",
                    variant: .primary,
                    keyboardShortcut: .return,
                    isEnabled: candidateCount > 0,
                    action: onConfirm
                )
            ]
        )
    }
}

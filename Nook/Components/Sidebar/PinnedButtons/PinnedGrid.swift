//
//      PinnedGrid.swift
//      Nook
//
//      Created by Maciek Bagiński on 30/07/2025.
//
import SwiftUI
import UniformTypeIdentifiers

struct PinnedGrid: View {
    let width: CGFloat
    let profileId: UUID?


    @EnvironmentObject var browserManager: BrowserManager
    @Environment(BrowserWindowState.self) private var windowState
    @Environment(WindowRegistry.self) private var windowRegistry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.nookSettings) var nookSettings
    @ObservedObject private var dragSession = NookDragSessionManager.shared

    init(width: CGFloat, profileId: UUID? = nil) {
        self.width = width
        self.profileId = profileId
    }

    var body: some View {
        let pinnedTabsConfiguration: PinnedTabsConfiguration = nookSettings.pinnedTabsLook
        // Use profile-filtered essentials
        let effectiveProfileId = profileId ?? windowState.currentProfileId ?? browserManager.currentProfile?.id
        let items: [Tab] = effectiveProfileId != nil
            ? browserManager.tabManager.essentialTabs(for: effectiveProfileId)
            : []
        let colsCount: Int = columnCount(for: width, itemCount: items.count)
        let columns: [GridItem] = makeColumns(count: colsCount)

        let shouldAnimate = (windowRegistry.activeWindow?.id == windowState.id) && !browserManager.isTransitioningProfile

        // Hide the essentials area entirely when nothing is pinned.
        if items.isEmpty {
            return AnyView(
                EmptyView()
                .onAppear {
                    dragSession.pinnedTabsConfig = pinnedTabsConfiguration
                    dragSession.itemCellSize[.essentials] = pinnedTabsConfiguration.minWidth
                    dragSession.itemCellSpacing[.essentials] = pinnedTabsConfiguration.gridSpacing
                    dragSession.itemCounts[.essentials] = 0
                    dragSession.gridColumnCount[.essentials] = colsCount
                }
            )
        }

        return AnyView(ZStack { // Container to support transitions
            VStack(spacing: 6) {
                ZStack(alignment: .top) {
                    NookDropZoneHostView(
                        zoneID: .essentials,
                        isVertical: false,
                        manager: dragSession
                    ) {
                        LazyVGrid(columns: columns, alignment: .center, spacing: pinnedTabsConfiguration.gridSpacing) {
                            let insertionIdx = essentialsInsertionIndex(itemCount: items.count)

                            ForEach(Array(items.enumerated()), id: \.element.id) { index, tab in
                                let isActive: Bool = (browserManager.currentTab(for: windowState)?.id == tab.id)
                                let title: String = safeTitle(tab)
                                let isDraggedItem = dragSession.draggedItem?.tabId == tab.id

                                // Insert a placeholder before this item if insertion index matches
                                if let ins = insertionIdx, ins == index, !isDraggedItem {
                                    essentialsPlaceholder
                                }

                                NookDragSourceView(
                                    item: NookDragItem(tabId: tab.id, title: title, urlString: tab.url.absoluteString),
                                    tab: tab,
                                    zoneID: .essentials,
                                    index: index,
                                    manager: dragSession
                                ) {
                                    PinnedTile(
                                        title: title,
                                        urlString: tab.url.absoluteString,
                                        icon: tab.favicon,
                                        isActive: isActive,
                                        onActivate: { browserManager.selectTab(tab, in: windowState) },
                                        onClose: { _ = browserManager.tabManager.completeTab(tab.id) },
                                        onRemovePin: { browserManager.tabManager.unpinTab(tab) }
                                    )
                                    .environmentObject(browserManager)
                                }
                                .opacity(isDraggedItem ? 0.0 : 1.0)
                            }

                            // Insertion placeholder at the end
                            if let ins = insertionIdx, ins >= items.count {
                                essentialsPlaceholder
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: essentialsInsertionIndex(itemCount: items.count))
                    }
                    .onAppear {
                        dragSession.pinnedTabsConfig = pinnedTabsConfiguration
                        dragSession.itemCellSize[.essentials] = pinnedTabsConfiguration.minWidth
                        dragSession.itemCellSpacing[.essentials] = pinnedTabsConfiguration.gridSpacing
                        dragSession.itemCounts[.essentials] = items.count
                        dragSession.gridColumnCount[.essentials] = colsCount
                    }
                    .onChange(of: items.count) { _, newCount in
                        dragSession.itemCounts[.essentials] = newCount
                    }
                    .onChange(of: colsCount) { _, newCols in
                        dragSession.gridColumnCount[.essentials] = newCols
                    }
                }
                .contentShape(Rectangle())
                .fixedSize(horizontal: false, vertical: true)
            }
            // Natural updates; avoid cross-profile transition artifacts
        }
        .animation(shouldAnimate ? .easeInOut(duration: 0.18) : nil, value: colsCount)
        .animation(shouldAnimate ? .easeInOut(duration: 0.18) : nil, value: items.count)
        .allowsHitTesting(!browserManager.isTransitioningProfile)
        .onChange(of: dragSession.pendingDrop) { _, drop in
            handleEssentialsDrop(drop, items: items)
        }
        .onChange(of: dragSession.pendingReorder) { _, reorder in
            handleEssentialsReorder(reorder, items: items)
        }
        )
    }

    // MARK: - Drop Handling

    private func handleEssentialsDrop(_ drop: PendingDrop?, items: [Tab]) {
        guard let drop = drop, drop.targetZone == .essentials else { return }
        let allTabs = browserManager.tabManager.allTabs()
        guard let tab = allTabs.first(where: { $0.id == drop.item.tabId }) else { return }
        let op = dragSession.makeDragOperation(from: drop, tab: tab)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            browserManager.tabManager.handleDragOperation(op)
        }
        dragSession.pendingDrop = nil
    }

    private func handleEssentialsReorder(_ reorder: PendingReorder?, items: [Tab]) {
        guard let reorder = reorder, reorder.zone == .essentials else { return }
        guard reorder.fromIndex < items.count else {
            dragSession.pendingReorder = nil
            return
        }
        let tab = items[reorder.fromIndex]
        let op = dragSession.makeDragOperation(from: reorder, tab: tab)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            browserManager.tabManager.handleDragOperation(op)
        }
        dragSession.pendingReorder = nil
    }

    /// Returns the insertion index for the essentials grid during a drag, or nil if no insertion should be shown.
    private func essentialsInsertionIndex(itemCount: Int) -> Int? {
        guard dragSession.isDragging,
              dragSession.activeZone == .essentials,
              let idx = dragSession.insertionIndex[.essentials] else {
            return nil
        }
        // During same-zone reorder, skip showing placeholder at the dragged item's original position
        if dragSession.sourceZone == .essentials,
           let from = dragSession.sourceIndex,
           idx == from {
            return nil
        }
        return idx
    }

    private var essentialsPlaceholder: some View {
        RoundedRectangle(cornerRadius: LexonTheme.controlCornerRadius, style: .continuous)
            .fill(LexonTheme.hoverFill(for: colorScheme))
            .frame(minWidth: nookSettings.pinnedTabsLook.minWidth, minHeight: nookSettings.pinnedTabsLook.minWidth)
    }

    private func safeTitle(_ tab: Tab) -> String {
        let t = tab.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? (tab.url.host ?? "New Tab") : t
    }

    private func columnCount(for width: CGFloat, itemCount: Int) -> Int {
        guard width > 0, itemCount > 0 else { return 1 }
        var cols = min(nookSettings.pinnedTabsLook.maxColumns, itemCount)
        while cols > 1 {
            let needed = CGFloat(cols) * nookSettings.pinnedTabsLook.minWidth + CGFloat(cols - 1) * nookSettings.pinnedTabsLook.gridSpacing
            if needed <= width { break }
            cols -= 1
        }
        return max(1, cols)
    }

    private func makeColumns(count: Int) -> [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(minimum: nookSettings.pinnedTabsLook.minWidth),
                spacing: nookSettings.pinnedTabsLook.gridSpacing,
                alignment: .center
            ),
            count: count
        )
    }
}

private struct PinnedTile: View {
    let title: String
    let urlString: String
    let icon: Image
    let isActive: Bool
    let onActivate: () -> Void
    let onClose: () -> Void
    let onRemovePin: () -> Void

    var body: some View {
        PinnedTabView(
            tabName: title,
            tabURL: urlString,
            tabIcon: icon,
            isActive: isActive,
            action: onActivate
        )
        .frame(maxWidth: .infinity)
        .contextMenu {
            Button(role: .destructive, action: onClose) {
                Label("Mark Done", systemImage: "checkmark")
            }
            Button(action: onRemovePin) {
                Label("Remove pinned tab", systemImage: "pin.slash")
            }
        }
    }
}

// MARK: - Preference Keys
// no-op

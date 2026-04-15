import SwiftUI

enum BrowserUtilityPanelLayout {
    static let windowInset: CGFloat = 12
    static let verticalSpacing: CGFloat = 10

    static func size(for panel: BrowserUtilityPanel) -> CGSize {
        switch panel {
        case .history:
            CGSize(width: 430, height: 520)
        case .downloads:
            CGSize(width: 400, height: 520)
        }
    }

    static func center(
        for panel: BrowserUtilityPanel,
        buttonFrame: CGRect?,
        in containerSize: CGSize,
        fallbackTopInset: CGFloat
    ) -> CGPoint {
        let panelSize = size(for: panel)
        let minX = windowInset + (panelSize.width / 2)
        let maxX = containerSize.width - windowInset - (panelSize.width / 2)
        let minY = windowInset + (panelSize.height / 2)
        let maxY = containerSize.height - windowInset - (panelSize.height / 2)

        let resolvedX = min(max(buttonFrame?.midX ?? maxX, minX), maxX)
        let preferredY = (buttonFrame?.maxY ?? fallbackTopInset) + verticalSpacing + (panelSize.height / 2)
        let resolvedY = min(max(preferredY, minY), maxY)

        return CGPoint(x: resolvedX, y: resolvedY)
    }
}

struct BrowserUtilityPanelButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: [BrowserUtilityPanel: CGRect] = [:]

    static func reduce(
        value: inout [BrowserUtilityPanel: CGRect],
        nextValue: () -> [BrowserUtilityPanel: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in
            newValue
        })
    }
}

extension AnyTransition {
    static var browserUtilityPanel: AnyTransition {
        .asymmetric(
            insertion: .offset(y: -14)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.98, anchor: .top)),
            removal: .offset(y: -8)
                .combined(with: .opacity)
        )
    }
}

//
//  SpaceSeparator.swift
//  Nook
//
//  Created by Maciek Bagiński on 30/07/2025.
//
import SwiftUI

struct SpaceSeparator: View {
    @Binding var isHovering: Bool
    let onClear: () -> Void
    @EnvironmentObject var browserManager: BrowserManager
    @State private var isClearHovered: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let hasTabs = browserManager.tabManager.currentSpace.map {
            !browserManager.tabManager.tabs(in: $0).isEmpty
        } ?? false

        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 100)
                .fill(isHovering ? LexonTheme.border(for: colorScheme) : Color.clear)
                .frame(height: 1)
                .animation(.smooth(duration: 0.1), value: isHovering)

            if hasTabs && isHovering {
                Button(action: onClear) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text("Clear")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(foregroundColor)
                    .padding(.horizontal, 4)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Clear all regular tabs")
                .transition(.blur.animation(.smooth(duration: 0.08)))
                .onHover { state in
                    isClearHovered = state
                }
            }
        }
        .frame(height: 2)
        .frame(maxWidth: .infinity)
    }
    
    var foregroundColor: Color {
        switch isClearHovered {
        case true:
            return LexonTheme.primaryText(for: colorScheme)
        default:
            return LexonTheme.tertiaryText(for: colorScheme)
        }
    }
}
 

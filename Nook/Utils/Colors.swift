import SwiftUI
import Foundation
#if canImport(AppKit)
import AppKit
#endif

struct AppColors {
    static let textPrimary = Color(hex: "121316")
    static let textSecondary = Color(hex: "5D6470")
    static let textTertiary = Color(hex: "8B92A0")
    static let textQuaternary = Color(hex: "B0B6C1")

    static let background = Color(hex: "F5F2EB")
    static let backgroundSecondary = Color(hex: "EBE6DB")

    static let controlBackground = Color.white.opacity(0.65)
    static let controlBackgroundHover = Color.black.opacity(0.14)
    static let controlBackgroundHoverLight = Color.white.opacity(0.12)
    static let controlBackgroundActive = Color.black.opacity(0.08)
    static let activeTab = Color.white.opacity(0.9)
    static let inactiveTab = Color.black.opacity(0.05)

    static let iconActiveLight = Color.white.opacity(0.88)
    static let iconDisabledLight = Color.white.opacity(0.34)
    static let iconHoverLight = Color.white.opacity(0.12)

    static let iconActiveDark = Color(hex: "262A33")
    static let iconDisabledDark = Color(hex: "8F96A3")
    static let iconHoverDark = Color.black.opacity(0.06)

    static let spaceTabActiveLight = Color.white.opacity(0.18)
    static let spaceTabHoverLight = Color.white.opacity(0.08)
    static let spaceTabTextLight = Color(hex: "F3F5F8")

    static let spaceTabActiveDark = Color.white.opacity(0.92)
    static let spaceTabHoverDark = Color.black.opacity(0.05)
    static let spaceTabTextDark = Color(hex: "1A1E27")

    static let pinnedTabActiveLight = Color.white.opacity(0.16)
    static let pinnedTabHoverLight = Color.white.opacity(0.11)
    static let pinnedTabIdleLight = Color.white.opacity(0.06)

    static let pinnedTabActiveDark = Color.white.opacity(0.94)
    static let pinnedTabHoverDark = Color.black.opacity(0.06)
    static let pinnedTabIdleDark = Color.black.opacity(0.03)

    static let sidebarTextLight = Color.white.opacity(0.68)
    static let sidebarTextDark = Color.black.opacity(0.58)
}

enum LexonTheme {
    static let sidebarRailWidth: CGFloat = 60
    static let sidebarRailItemSize: CGFloat = 40
    static let outerCornerRadius: CGFloat = 26
    static let panelCornerRadius: CGFloat = 18
    static let pillCornerRadius: CGFloat = 14
    static let controlCornerRadius: CGFloat = 12
    static let topBarHeight: CGFloat = 44
    static let thinBorder: CGFloat = 1

    static func windowWash(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(hex: "0D0E10").opacity(0.92)
            : Color(hex: "F4F1E8").opacity(0.94)
    }

    static func windowGradientTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(hex: "15181E").opacity(0.55)
            : Color(hex: "FFFFFF").opacity(0.46)
    }

    static func sidebarShell(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(hex: "1B1C20").opacity(0.96)
            : Color(hex: "FBF9F5").opacity(0.92)
    }

    static func railFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.045)
            : Color.black.opacity(0.035)
    }

    static func contentPanelFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.045)
            : Color.white.opacity(0.74)
    }

    static func chromeFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(hex: "171A1F").opacity(0.9)
            : Color(hex: "FCFBF8").opacity(0.94)
    }

    static func fieldFill(for colorScheme: ColorScheme, isHovered: Bool = false) -> Color {
        let base = colorScheme == .dark
            ? Color.white.opacity(isHovered ? 0.12 : 0.08)
            : Color.black.opacity(isHovered ? 0.07 : 0.045)
        return base
    }

    static func activeFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.07)
    }

    static func hoverFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color.black.opacity(0.045)
    }

    static func selectedFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.black.opacity(0.085)
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    static func strongBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.12)
    }

    static func shadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.32)
            : Color.black.opacity(0.08)
    }

    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "F5F7FA") : Color(hex: "17191F")
    }

    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.52)
    }

    static func tertiaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.42) : Color.black.opacity(0.36)
    }
}

enum SidebarLayoutMetrics {
    static let shellPadding: CGFloat = 10
    static let shellSpacing: CGFloat = 12
    static let panelInset: CGFloat = 10
    static let railTopInset: CGFloat = 54

    static func contentWidth(for sidebarWidth: CGFloat) -> CGFloat {
        let availableWidth = sidebarWidth
            - (shellPadding * 2)
            - SidebarLayoutMetrics.shellSpacing
            - LexonTheme.sidebarRailWidth
            - (panelInset * 2)
        return max(availableWidth, 0)
    }
}

struct LexonBrandMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "CFC8F8"), Color(hex: "E9E7FF")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("L")
                .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "2B2647"))
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 6)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(
            in: CharacterSet.alphanumerics.inverted
        )
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (
                255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17
            )
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (
                int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF
            )
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHexString(includeAlpha: Bool = false) -> String? {
        let ns = NSColor(self)
        return ns.toHexString(includeAlpha: includeAlpha)
    }
    
    var perceivedBrightness: CGFloat {
            guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return 0.5 }
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            if a <= 0.01 { return 1.0 }

            let brightness = (0.299 * r + 0.587 * g + 0.114 * b)
            return brightness * a + (1 - a)
        }

        var isPerceivedDark: Bool {
            perceivedBrightness < 0.6
        }
}

extension NSColor {
    func toHexString(includeAlpha: Bool = false) -> String? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        if includeAlpha {
            let ai = Int(round(a * 255))
            return String(format: "#%02X%02X%02X%02X", ai, ri, gi, bi)
        } else {
            return String(format: "#%02X%02X%02X", ri, gi, bi)
        }
    }

    var perceivedBrightness: CGFloat {
        guard let rgb = usingColorSpace(.sRGB) else { return 0.5 }
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)

        if a <= 0.01 { return 1.0 }

        let brightness = (0.299 * r + 0.587 * g + 0.114 * b)
        return brightness * a + (1 - a)
    }

    var isPerceivedDark: Bool {
        perceivedBrightness < 0.6
    }
}

extension NSImage {
    var singlePixelColor: NSColor? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        // Create a bitmap context to read pixel data
        let width = 1
        let height = 1
        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var pixelData: [UInt8] = [0, 0, 0, 0]
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        // Draw the image into the context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Extract RGB values (pixelData is RGBA format with premultipliedLast)
        let red = CGFloat(pixelData[0]) / 255.0
        let green = CGFloat(pixelData[1]) / 255.0
        let blue = CGFloat(pixelData[2]) / 255.0
        let alpha = CGFloat(pixelData[3]) / 255.0
        
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}


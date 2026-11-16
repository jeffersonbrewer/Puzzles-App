import SwiftUI
import UIKit

/// Fixed colors that don't follow the user's theme color.
enum Theme {
    static let wrongText = Color(red: 0.86, green: 0.20, blue: 0.24)
    static let wrongCell = Color(red: 0.86, green: 0.20, blue: 0.24).opacity(0.14)
    static let patternCell = Color(red: 0.98, green: 0.72, blue: 0.20).opacity(0.38)
    static let houseShade = Color(red: 0.98, green: 0.72, blue: 0.20).opacity(0.12)
    static let patternCandidate = Color(red: 0.80, green: 0.45, blue: 0.00)
    static let elimination = Color(red: 0.86, green: 0.20, blue: 0.24)
    static let placement = Color(red: 0.15, green: 0.62, blue: 0.35)
    static let gridLine = Color.primary.opacity(0.22)
    static let boxLine = Color.primary.opacity(0.75)
}

/// The user's theme color, described by a hue (0...1 around the color wheel)
/// and a tone (0 = light and soft, 1 = deep and rich).
struct ThemeColor: Equatable {
    var hue: Double
    var tone: Double

    static let hueKey = "theme.hue"
    static let toneKey = "theme.tone"

    static let teal = ThemeColor(hue: 0.528, tone: 0.80)

    static let presets: [ThemePreset] = [
        ThemePreset(name: "Teal", color: .teal),
        ThemePreset(name: "Forest", color: ThemeColor(hue: 0.38, tone: 0.88)),
        ThemePreset(name: "Sky", color: ThemeColor(hue: 0.57, tone: 0.30)),
        ThemePreset(name: "Ocean", color: ThemeColor(hue: 0.61, tone: 0.82)),
        ThemePreset(name: "Indigo", color: ThemeColor(hue: 0.70, tone: 0.70)),
        ThemePreset(name: "Plum", color: ThemeColor(hue: 0.84, tone: 0.72)),
        ThemePreset(name: "Coral", color: ThemeColor(hue: 0.02, tone: 0.45)),
        ThemePreset(name: "Amber", color: ThemeColor(hue: 0.09, tone: 0.62)),
    ]

    func saturation(dark: Bool) -> Double {
        let s = 0.35 + 0.45 * tone
        return dark ? s * 0.8 : s
    }

    func brightness(dark: Bool) -> Double {
        let b = 0.95 - 0.45 * tone
        // In dark mode deep colors get lifted so they stay readable on black.
        return dark ? min(1, max(b, 0.55) + 0.2) : b
    }

    /// Adapts automatically between light and dark mode.
    var color: Color {
        Color(uiColor: UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            return UIColor(hue: hue, saturation: saturation(dark: dark), brightness: brightness(dark: dark), alpha: 1)
        })
    }

    /// The same hue at a given tone, used to draw the tone slider.
    func atTone(_ t: Double) -> Color {
        ThemeColor(hue: hue, tone: t).color
    }
}

struct ThemePreset: Identifiable {
    let name: String
    let color: ThemeColor
    var id: String { name }
}

/// The screen background: a hue plus a strength (0 = plain system background,
/// 1 = strongest tint). Light mode gets a pale wash; dark mode a deep shade.
struct BackgroundColor: Equatable {
    var hue: Double
    var strength: Double

    static let hueKey = "theme.backgroundHue"
    static let strengthKey = "theme.backgroundStrength"

    static let plain = BackgroundColor(hue: 0.11, strength: 0)

    static let presets: [BackgroundPreset] = [
        BackgroundPreset(name: "Plain", background: .plain),
        BackgroundPreset(name: "Paper", background: BackgroundColor(hue: 0.11, strength: 0.30)),
        BackgroundPreset(name: "Sand", background: BackgroundColor(hue: 0.08, strength: 0.55)),
        BackgroundPreset(name: "Sage", background: BackgroundColor(hue: 0.30, strength: 0.45)),
        BackgroundPreset(name: "Mint", background: BackgroundColor(hue: 0.43, strength: 0.40)),
        BackgroundPreset(name: "Sky", background: BackgroundColor(hue: 0.56, strength: 0.45)),
        BackgroundPreset(name: "Lavender", background: BackgroundColor(hue: 0.72, strength: 0.40)),
        BackgroundPreset(name: "Blush", background: BackgroundColor(hue: 0.97, strength: 0.35)),
    ]

    var isPlain: Bool { strength < 0.02 }

    static func uiColor(hue: Double, strength: Double, dark: Bool) -> UIColor {
        if dark {
            return UIColor(hue: hue, saturation: 0.30 + 0.30 * strength, brightness: 0.07 + 0.13 * strength, alpha: 1)
        }
        return UIColor(hue: hue, saturation: 0.05 + 0.30 * strength, brightness: 0.99 - 0.08 * strength, alpha: 1)
    }

    /// nil means "use the normal system background".
    var color: Color? {
        guard !isPlain else { return nil }
        let h = hue, s = strength
        return Color(uiColor: UIColor { traits in
            BackgroundColor.uiColor(hue: h, strength: s, dark: traits.userInterfaceStyle == .dark)
        })
    }

    /// A swatch color for pickers (plain shows the system background).
    var swatch: Color { color ?? Color(.systemBackground) }

    /// The same hue at a given strength, used to draw the strength slider.
    func atStrength(_ s: Double) -> Color {
        Color(uiColor: UIColor { traits in
            BackgroundColor.uiColor(hue: hue, strength: s, dark: traits.userInterfaceStyle == .dark)
        })
    }
}

struct BackgroundPreset: Identifiable {
    let name: String
    let background: BackgroundColor
    var id: String { name }
}

/// Colors derived from the user's theme, available to every view through
/// `@Environment(\.palette)`.
struct Palette {
    var accent: Color
    /// nil = plain system background.
    var background: Color? = nil

    var selectedCell: Color { accent.opacity(0.38) }
    var sameDigit: Color { accent.opacity(0.22) }
    var peerCell: Color { accent.opacity(0.08) }

    /// Raised surfaces such as the number pad and cards.
    var card: Color {
        if background == nil { return Color(.secondarySystemBackground) }
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.10) : UIColor(white: 1, alpha: 0.70)
        })
    }

    static let standard = Palette(accent: ThemeColor.teal.color)
}

/// Paints the screen with the user's background color, if they picked one.
struct ThemedBackground: ViewModifier {
    @Environment(\.palette) private var palette

    @ViewBuilder
    func body(content: Content) -> some View {
        if let bg = palette.background {
            content
                .scrollContentBackground(.hidden)
                .background(bg.ignoresSafeArea())
        } else {
            content
        }
    }
}

extension View {
    func themedBackground() -> some View { modifier(ThemedBackground()) }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.standard
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// Reads the saved theme color and applies it to everything inside.
struct ThemedRoot<Content: View>: View {
    @AppStorage(ThemeColor.hueKey) private var hue = ThemeColor.teal.hue
    @AppStorage(ThemeColor.toneKey) private var tone = ThemeColor.teal.tone
    @AppStorage(BackgroundColor.hueKey) private var bgHue = BackgroundColor.plain.hue
    @AppStorage(BackgroundColor.strengthKey) private var bgStrength = BackgroundColor.plain.strength
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let accent = ThemeColor(hue: hue, tone: tone).color
        content
            .tint(accent)
            .environment(\.palette, Palette(accent: accent, background: BackgroundColor(hue: bgHue, strength: bgStrength).color))
    }
}

func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

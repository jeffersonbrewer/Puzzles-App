import SwiftUI

/// Pick the app's colors: the screen background and the accent used for
/// your numbers, highlights and buttons. Each has presets plus two
/// gradient sliders. A live preview of the board sits at the top.
struct ThemeSettingsView: View {
    private enum Part: String, CaseIterable, Identifiable {
        case background = "Background"
        case accent = "Accent"
        var id: String { rawValue }
    }

    @AppStorage(ThemeColor.hueKey) private var hue = ThemeColor.teal.hue
    @AppStorage(ThemeColor.toneKey) private var tone = ThemeColor.teal.tone
    @AppStorage(BackgroundColor.hueKey) private var bgHue = BackgroundColor.plain.hue
    @AppStorage(BackgroundColor.strengthKey) private var bgStrength = BackgroundColor.plain.strength
    @State private var part: Part = .background

    private var current: ThemeColor { ThemeColor(hue: hue, tone: tone) }
    private var currentBackground: BackgroundColor { BackgroundColor(hue: bgHue, strength: bgStrength) }

    var body: some View {
        Form {
            Section {
                ThemePreview(accent: current.color, background: currentBackground.swatch)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                Picker("Part", selection: $part) {
                    ForEach(Part.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            switch part {
            case .background: backgroundSections
            case .accent: accentSections
            }
        }
        .themedBackground()
        .navigationTitle("Colors")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Background

    private var backgroundItems: [(name: String, color: Color, selected: Bool)] {
        let now = currentBackground
        return BackgroundColor.presets.map { preset in
            let bg = preset.background
            let selected: Bool = bg.isPlain ? now.isPlain : bg == now
            return (name: preset.name, color: bg.swatch, selected: selected)
        }
    }

    @ViewBuilder
    private var backgroundSections: some View {
        Section("Presets") {
            swatchGrid(backgroundItems) { index in
                let preset = BackgroundColor.presets[index]
                bgHue = preset.background.hue
                bgStrength = preset.background.strength
            }
        }
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Color")
                GradientSlider(
                    value: $bgHue,
                    colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12).map { BackgroundColor(hue: $0, strength: max(bgStrength, 0.6)).swatch },
                    thumb: currentBackground.swatch
                )
                .accessibilityLabel("Background color")
            }
            .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Strength")
                    Spacer()
                    Text(currentBackground.isPlain ? "Plain" : bgStrength < 0.4 ? "Subtle" : bgStrength < 0.75 ? "Medium" : "Strong")
                        .foregroundStyle(.secondary)
                }
                GradientSlider(
                    value: $bgStrength,
                    colors: [currentBackground.atStrength(0), currentBackground.atStrength(0.5), currentBackground.atStrength(1)],
                    thumb: currentBackground.swatch
                )
                .accessibilityLabel("Background strength")
            }
            .padding(.vertical, 4)
        } header: {
            Text("Custom")
        } footer: {
            Text("Pick a color, then choose how strong the tint is. All the way left is the plain background. In dark mode it becomes a deep shade of the same color.")
        }
    }

    // MARK: Accent

    @ViewBuilder
    private var accentSections: some View {
        Section("Presets") {
            swatchGrid(ThemeColor.presets.map { (name: $0.name, color: $0.color.color, selected: $0.color == current) }) { index in
                let preset = ThemeColor.presets[index]
                hue = preset.color.hue
                tone = preset.color.tone
            }
        }
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Color")
                GradientSlider(
                    value: $hue,
                    colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12).map { ThemeColor(hue: $0, tone: tone).color },
                    thumb: current.color
                )
                .accessibilityLabel("Accent color")
            }
            .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Tone")
                    Spacer()
                    Text(tone < 0.35 ? "Light" : tone < 0.7 ? "Medium" : "Deep")
                        .foregroundStyle(.secondary)
                }
                GradientSlider(
                    value: $tone,
                    colors: [current.atTone(0), current.atTone(0.5), current.atTone(1)],
                    thumb: current.color
                )
                .accessibilityLabel("Accent tone")
            }
            .padding(.vertical, 4)
        } header: {
            Text("Custom")
        } footer: {
            Text("The accent colors your numbers, highlights and buttons. It brightens itself in dark mode so it stays readable.")
        }
        Section {
            Button("Reset colors") {
                hue = ThemeColor.teal.hue
                tone = ThemeColor.teal.tone
                bgHue = BackgroundColor.plain.hue
                bgStrength = BackgroundColor.plain.strength
            }
        }
    }

    private func swatchGrid(_ items: [(name: String, color: Color, selected: Bool)], onPick: @escaping (Int) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { onPick(index) }
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(item.color)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                            .frame(width: 40, height: 40)
                            .overlay {
                                if item.selected {
                                    Circle().strokeBorder(Color.primary, lineWidth: 2.5)
                                        .padding(-5)
                                }
                            }
                        Text(item.name)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.name)
                .accessibilityAddTraits(item.selected ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}

/// A capsule filled with a gradient and a round draggable thumb. `value` is 0...1.
struct GradientSlider: View {
    @Binding var value: Double
    let colors: [Color]
    let thumb: Color

    private let height: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let usable = max(width - height, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                Circle()
                    .fill(thumb)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .frame(width: height + 6, height: height + 6)
                    .offset(x: CGFloat(value) * usable - 3)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let v = (g.location.x - height / 2) / usable
                        value = min(max(Double(v), 0), 1)
                    }
            )
        }
        .frame(height: height + 6)
        .accessibilityElement()
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 0.05, 1)
            case .decrement: value = max(value - 0.05, 0)
            @unknown default: break
            }
        }
    }
}

/// A small slice of the game screen showing how the color looks.
private struct ThemePreview: View {
    let accent: Color
    let background: Color

    var body: some View {
        let palette = Palette(accent: accent)
        let values = [5, 3, 4, 0, 7, 0, 9, 0, 0,
                      6, 0, 0, 1, 9, 5, 0, 0, 0,
                      0, 9, 8, 0, 0, 0, 0, 6, 0]
        let user: Set<Int> = [2, 6]
        let selected = 6
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { c in
                            let i = r * 9 + c
                            let v = values[i]
                            ZStack {
                                if i == selected { palette.selectedCell }
                                else if v == values[selected] { palette.sameDigit }
                                else if r == 0 || (c / 3 == 2) { palette.peerCell }
                                else { Color.clear }
                                if v != 0 {
                                    Text("\(v)")
                                        .font(.system(size: 15, weight: user.contains(i) ? .regular : .semibold, design: .rounded))
                                        .foregroundStyle(user.contains(i) ? accent : .primary)
                                }
                            }
                            .frame(width: 24, height: 24)
                            .overlay(Rectangle().stroke(Theme.gridLine, lineWidth: 0.5))
                        }
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.boxLine, lineWidth: 1.5))
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 34)
                    .background(accent, in: RoundedRectangle(cornerRadius: 9))
                Text("Auto On").font(.caption2).foregroundStyle(accent)
            }
        }
        .padding(14)
        .background(background)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the board in these colors")
    }
}

/// A settings row: "Colors" with swatches of the background and accent.
struct ThemeColorRow: View {
    @Environment(\.palette) private var palette

    var body: some View {
        HStack {
            Text("Colors")
            Spacer()
            ZStack {
                Circle().fill(palette.background ?? Color(.systemBackground))
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1))
                    .frame(width: 22, height: 22)
                    .offset(x: -12)
                Circle().fill(palette.accent).frame(width: 22, height: 22)
            }
        }
    }
}

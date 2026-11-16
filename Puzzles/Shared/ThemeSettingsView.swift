import SwiftUI

/// Pick the app's theme color: preset swatches, or any color with the
/// color and tone sliders. Includes a live preview of the Sudoku board.
struct ThemeSettingsView: View {
    @AppStorage(ThemeColor.hueKey) private var hue = ThemeColor.teal.hue
    @AppStorage(ThemeColor.toneKey) private var tone = ThemeColor.teal.tone

    private var current: ThemeColor { ThemeColor(hue: hue, tone: tone) }

    var body: some View {
        Form {
            Section {
                ThemePreview(accent: current.color)
                    .listRowInsets(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14))
            }

            Section("Presets") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
                    ForEach(ThemeColor.presets) { preset in
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                hue = preset.color.hue
                                tone = preset.color.tone
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(preset.color.color)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        if preset.color == current {
                                            Circle().strokeBorder(Color.primary, lineWidth: 2.5)
                                                .padding(-5)
                                        }
                                    }
                                Text(preset.name)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 64)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(preset.name)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Color")
                    GradientSlider(
                        value: $hue,
                        colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12).map { ThemeColor(hue: $0, tone: tone).color },
                        thumb: current.color
                    )
                    .accessibilityLabel("Color")
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
                    .accessibilityLabel("Tone")
                }
                .padding(.vertical, 4)
            } header: {
                Text("Custom")
            } footer: {
                Text("Drag to choose any color, then make it lighter or deeper. The color adjusts itself for dark mode.")
            }

            Section {
                Button("Reset to Teal") {
                    withAnimation { hue = ThemeColor.teal.hue; tone = ThemeColor.teal.tone }
                }
            }
        }
        .navigationTitle("Theme Color")
        .navigationBarTitleDisplayMode(.inline)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the board in this color")
    }
}

/// A settings row: "Theme Color" with a swatch of the current color.
struct ThemeColorRow: View {
    @Environment(\.palette) private var palette

    var body: some View {
        HStack {
            Text("Theme Color")
            Spacer()
            Circle().fill(palette.accent).frame(width: 22, height: 22)
        }
    }
}

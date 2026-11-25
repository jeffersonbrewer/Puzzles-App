import SwiftUI
import UIKit

/// Tile colors, adapted for light and dark mode.
enum TileInk {
    static let face = adaptive(light: UIColor(red: 0.99, green: 0.97, blue: 0.92, alpha: 1),
                               dark: UIColor(red: 0.21, green: 0.21, blue: 0.22, alpha: 1))
    /// The thin band between the face and the colored back.
    static let band = adaptive(light: UIColor(red: 0.88, green: 0.85, blue: 0.77, alpha: 1),
                               dark: UIColor(red: 0.33, green: 0.33, blue: 0.35, alpha: 1))
    static let edge = adaptive(light: UIColor(white: 0, alpha: 0.30), dark: UIColor(white: 1, alpha: 0.22))
    /// Laid over tiles that can't be played yet.
    static let shade = adaptive(light: UIColor(white: 0, alpha: 0.20), dark: UIColor(white: 0, alpha: 0.42))
    static let ink = adaptive(light: UIColor(white: 0.13, alpha: 1), dark: UIColor(white: 0.93, alpha: 1))
    static let red = adaptive(light: UIColor(red: 0.80, green: 0.14, blue: 0.16, alpha: 1),
                              dark: UIColor(red: 1.00, green: 0.45, blue: 0.43, alpha: 1))
    static let green = adaptive(light: UIColor(red: 0.09, green: 0.50, blue: 0.29, alpha: 1),
                                dark: UIColor(red: 0.38, green: 0.80, blue: 0.52, alpha: 1))
    static let blue = adaptive(light: UIColor(red: 0.12, green: 0.33, blue: 0.66, alpha: 1),
                               dark: UIColor(red: 0.52, green: 0.69, blue: 1.00, alpha: 1))
    static let gold = adaptive(light: UIColor(red: 0.85, green: 0.58, blue: 0.05, alpha: 1),
                               dark: UIColor(red: 1.00, green: 0.76, blue: 0.30, alpha: 1))
    static let pink = adaptive(light: UIColor(red: 0.89, green: 0.38, blue: 0.58, alpha: 1),
                               dark: UIColor(red: 1.00, green: 0.56, blue: 0.72, alpha: 1))
    static let purple = adaptive(light: UIColor(red: 0.52, green: 0.33, blue: 0.80, alpha: 1),
                                 dark: UIColor(red: 0.72, green: 0.58, blue: 1.00, alpha: 1))
    static let brown = adaptive(light: UIColor(red: 0.66, green: 0.38, blue: 0.12, alpha: 1),
                                dark: UIColor(red: 0.93, green: 0.62, blue: 0.33, alpha: 1))

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// How a tile should look right now.
struct TileState: Equatable {
    var selected = false
    var hinted = false
    var dimmed = false
    var rejected = false
}

/// A mahjong tile seen from slightly above: the face, a thin band and the
/// back in the user's theme color showing along the right and bottom edges.
/// Everything scales with `width`.
struct MahjongTileView: View {
    @Environment(\.palette) private var palette
    let tile: MahjongTile
    let width: CGFloat
    let height: CGFloat
    /// How far the tile's sides show below and to the right of the face.
    let depth: CGFloat
    var state = TileState()

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: width * 0.13, style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            shape
                .fill(palette.accent)
                .overlay { shape.fill(Color.black.opacity(0.18)) }
                .frame(width: width, height: height)
                .offset(x: depth, y: depth)
            shape
                .fill(TileInk.band)
                .frame(width: width, height: height)
                .offset(x: depth * 0.45, y: depth * 0.45)
            face
        }
        .frame(width: width + depth, height: height + depth, alignment: .topLeading)
        .contentShape(Path(CGRect(x: 0, y: 0, width: width, height: height)))
    }

    private var face: some View {
        ZStack {
            shape.fill(TileInk.face)
            MahjongTileArt(tile: tile, width: width, height: height)
            if state.selected {
                shape.fill(palette.accent.opacity(0.30))
            } else if state.dimmed {
                shape.fill(TileInk.shade)
            }
            shape.strokeBorder(borderColor, lineWidth: borderWidth)
        }
        .frame(width: width, height: height)
    }

    private var borderColor: Color {
        if state.rejected { return Theme.wrongText }
        if state.selected { return palette.accent }
        if state.hinted { return Theme.patternCandidate }
        return TileInk.edge
    }

    private var borderWidth: CGFloat {
        state.rejected || state.selected || state.hinted ? max(2, width * 0.07) : 0.75
    }
}

/// The picture on a tile's face. All of it is drawn here, not taken from
/// any existing game.
struct MahjongTileArt: View {
    let tile: MahjongTile
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        switch tile.kind {
        case .dots(let n):
            Canvas { ctx, size in DotsArt.draw(n, in: ctx, size: size) }
        case .bamboo(let n):
            Canvas { ctx, size in BambooArt.draw(n, in: ctx, size: size) }
        case .characters(let n):
            characters(n)
        case .wind(let i):
            wind(i)
        case .dragon(let i):
            dragon(i)
        case .flower(let i):
            Canvas { ctx, size in FlowerArt.draw(i, in: ctx, size: size) }
        case .season(let i):
            season(i)
        }
    }

    private static let numerals = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]

    private func characters(_ n: Int) -> some View {
        VStack(spacing: -height * 0.04) {
            Text(Self.numerals[n - 1])
                .font(.system(size: width * 0.44, weight: .heavy))
                .foregroundStyle(TileInk.blue)
            Text("萬")
                .font(.system(size: width * 0.42, weight: .bold))
                .foregroundStyle(TileInk.red)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .frame(width: width, height: height)
        .overlay(alignment: .topLeading) { cornerIndex("\(n)") }
    }

    private func wind(_ i: Int) -> some View {
        Text(["東", "南", "西", "北"][i])
            .font(.system(size: width * 0.60, weight: .bold))
            .foregroundStyle(TileInk.ink)
            .frame(width: width, height: height)
            .overlay(alignment: .topLeading) { cornerIndex(["E", "S", "W", "N"][i]) }
    }

    @ViewBuilder
    private func dragon(_ i: Int) -> some View {
        switch i {
        case 0:
            Text("中")
                .font(.system(size: width * 0.64, weight: .heavy))
                .foregroundStyle(TileInk.red)
                .frame(width: width, height: height)
        case 1:
            Text("發")
                .font(.system(size: width * 0.60, weight: .heavy))
                .foregroundStyle(TileInk.green)
                .frame(width: width, height: height)
        default:
            // The white dragon: a double frame.
            ZStack {
                RoundedRectangle(cornerRadius: width * 0.08)
                    .strokeBorder(TileInk.blue, lineWidth: width * 0.06)
                    .padding(width * 0.16)
                RoundedRectangle(cornerRadius: width * 0.04)
                    .strokeBorder(TileInk.blue.opacity(0.6), lineWidth: width * 0.025)
                    .padding(width * 0.27)
            }
            .frame(width: width, height: height)
        }
    }

    private func season(_ i: Int) -> some View {
        let symbol = ["leaf.fill", "sun.max.fill", "moon.fill", "snowflake"][i]
        let color = [TileInk.green, TileInk.gold, TileInk.brown, TileInk.blue][i]
        return ZStack {
            Circle()
                .strokeBorder(color, lineWidth: width * 0.045)
                .frame(width: width * 0.74, height: width * 0.74)
            Image(systemName: symbol)
                .font(.system(size: width * 0.38, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: width, height: height)
    }

    private func cornerIndex(_ text: String) -> some View {
        Text(text)
            .font(.system(size: width * 0.2, weight: .bold, design: .rounded))
            .foregroundStyle(TileInk.ink.opacity(0.55))
            .padding(.leading, width * 0.09)
            .padding(.top, width * 0.05)
    }
}

// MARK: - Drawn suits

/// A point in the art box, 0...1 across and down.
private typealias Spot = (x: CGFloat, y: CGFloat)

/// The area inside the face that the drawings use.
private func artBox(_ size: CGSize) -> CGRect {
    CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.12, dy: size.height * 0.10)
}

private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
}

private enum DotsArt {
    /// Spots, radius (as a share of the box width) and a color per spot.
    static func pattern(_ n: Int) -> (spots: [Spot], radius: CGFloat, colors: [Color]) {
        let b = TileInk.blue, g = TileInk.green, r = TileInk.red
        switch n {
        case 1: return ([(0.5, 0.5)], 0.38, [r])
        case 2: return ([(0.5, 0.26), (0.5, 0.74)], 0.25, [g, b])
        case 3: return ([(0.22, 0.18), (0.5, 0.5), (0.78, 0.82)], 0.19, [b, r, g])
        case 4: return ([(0.28, 0.28), (0.72, 0.28), (0.28, 0.72), (0.72, 0.72)], 0.19, [b, g, g, b])
        case 5: return ([(0.22, 0.2), (0.78, 0.2), (0.5, 0.5), (0.22, 0.8), (0.78, 0.8)], 0.17, [b, g, r, g, b])
        case 6:
            return ([(0.3, 0.18), (0.7, 0.18), (0.3, 0.5), (0.7, 0.5), (0.3, 0.82), (0.7, 0.82)], 0.165,
                    [g, g, r, r, r, r])
        case 7:
            return ([(0.22, 0.12), (0.5, 0.27), (0.78, 0.42), (0.3, 0.66), (0.7, 0.66), (0.3, 0.9), (0.7, 0.9)], 0.145,
                    [g, g, g, r, r, r, r])
        case 8:
            return ([(0.3, 0.12), (0.7, 0.12), (0.3, 0.37), (0.7, 0.37), (0.3, 0.63), (0.7, 0.63), (0.3, 0.88), (0.7, 0.88)],
                    0.15, Array(repeating: b, count: 8))
        default:
            var spots: [Spot] = []
            for y in [0.18, 0.5, 0.82] as [CGFloat] {
                for x in [0.2, 0.5, 0.8] as [CGFloat] { spots.append((x, y)) }
            }
            return (spots, 0.14, [b, b, b, r, r, r, g, g, g])
        }
    }

    static func draw(_ n: Int, in ctx: GraphicsContext, size: CGSize) {
        let box = artBox(size)
        let (spots, share, colors) = pattern(n)
        let radius = share * box.width
        for (spot, color) in zip(spots, colors) {
            let center = CGPoint(x: box.minX + spot.x * box.width, y: box.minY + spot.y * box.height)
            ctx.fill(circle(center, radius), with: .color(color))
            ctx.fill(circle(center, radius * 0.62), with: .color(TileInk.face))
            ctx.fill(circle(center, radius * 0.3), with: .color(color))
        }
    }
}

private enum BambooArt {
    /// Stalk centers, stalk length (as a share of the box height) and which stalks are red.
    static func pattern(_ n: Int) -> (spots: [Spot], length: CGFloat, red: Set<Int>) {
        let two: [CGFloat] = [0.27, 0.73]
        func grid(_ xs: [CGFloat], _ ys: [CGFloat]) -> [Spot] { ys.flatMap { y in xs.map { x in (x, y) } } }
        switch n {
        case 2: return ([(0.5, 0.27), (0.5, 0.73)], 0.38, [])
        case 3: return ([(0.5, 0.27), (0.28, 0.73), (0.72, 0.73)], 0.38, [])
        case 4: return (grid([0.3, 0.7], two), 0.38, [])
        case 5: return ([(0.2, 0.27), (0.8, 0.27), (0.5, 0.5), (0.2, 0.73), (0.8, 0.73)], 0.38, [2])
        case 6: return (grid([0.2, 0.5, 0.8], two), 0.38, [])
        case 7: return ([(0.5, 0.16)] + grid([0.2, 0.5, 0.8], [0.5, 0.84]), 0.26, [0])
        case 8: return (grid([0.14, 0.38, 0.62, 0.86], two), 0.38, [1, 2, 5, 6])
        default: return (grid([0.2, 0.5, 0.8], [0.16, 0.5, 0.84]), 0.27, [1, 4, 7])
        }
    }

    static func draw(_ n: Int, in ctx: GraphicsContext, size: CGSize) {
        let box = artBox(size)
        guard n > 1 else { return drawOne(in: ctx, box: box) }
        let (spots, share, red) = pattern(n)
        let width = box.width * (n == 8 ? 0.12 : 0.14)
        let length = share * box.height
        for (i, spot) in spots.enumerated() {
            let center = CGPoint(x: box.minX + spot.x * box.width, y: box.minY + spot.y * box.height)
            stalk(in: ctx, center: center, width: width, length: length, color: red.contains(i) ? TileInk.red : TileInk.green)
        }
    }

    /// One stalk: a rounded stick with a joint across the middle.
    static func stalk(in ctx: GraphicsContext, center: CGPoint, width: CGFloat, length: CGFloat, color: Color) {
        let rect = CGRect(x: center.x - width / 2, y: center.y - length / 2, width: width, height: length)
        ctx.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(color))
        var joint = Path()
        joint.move(to: CGPoint(x: rect.minX, y: center.y))
        joint.addLine(to: CGPoint(x: rect.maxX, y: center.y))
        ctx.stroke(joint, with: .color(TileInk.face), lineWidth: max(1, width * 0.22))
    }

    /// The one of bamboo: a single tall shoot with two leaves and a red bud.
    static func drawOne(in ctx: GraphicsContext, box: CGRect) {
        let width = box.width * 0.2
        let center = CGPoint(x: box.midX, y: box.midY + box.height * 0.08)
        let length = box.height * 0.78
        stalk(in: ctx, center: center, width: width, length: length, color: TileInk.green)
        for side in [-1.0, 1.0] as [CGFloat] {
            var leafCtx = ctx
            leafCtx.translateBy(x: center.x + side * width * 0.5, y: center.y - length * 0.12)
            leafCtx.rotate(by: .degrees(Double(side) * 55))
            let leaf = Path(ellipseIn: CGRect(x: -width * 0.45, y: -width * 2.2, width: width * 0.9, height: width * 2.2))
            leafCtx.fill(leaf, with: .color(TileInk.green))
        }
        let budCenter = CGPoint(x: center.x, y: center.y - length / 2 - width * 0.2)
        ctx.fill(circle(budCenter, width * 0.55), with: .color(TileInk.red))
    }
}

private enum FlowerArt {
    static func draw(_ i: Int, in ctx: GraphicsContext, size: CGSize) {
        let box = artBox(size)
        let petals = [5, 3, 12, 8][i]
        let color = [TileInk.pink, TileInk.purple, TileInk.gold, TileInk.red][i]
        let petalWidth = box.width * [0.30, 0.26, 0.11, 0.18][i]
        let petalLength = box.width * [0.30, 0.40, 0.36, 0.34][i]
        let center = CGPoint(x: box.midX, y: box.minY + box.height * 0.40)

        // Stem and leaf.
        var stem = Path()
        stem.move(to: center)
        stem.addLine(to: CGPoint(x: center.x, y: box.maxY))
        ctx.stroke(stem, with: .color(TileInk.green), lineWidth: max(1.5, box.width * 0.07))
        var leafCtx = ctx
        leafCtx.translateBy(x: center.x, y: box.maxY - box.height * 0.18)
        leafCtx.rotate(by: .degrees(50))
        leafCtx.fill(Path(ellipseIn: CGRect(x: -box.width * 0.08, y: -box.width * 0.34, width: box.width * 0.16, height: box.width * 0.34)),
                     with: .color(TileInk.green))

        for k in 0..<petals {
            var petalCtx = ctx
            petalCtx.translateBy(x: center.x, y: center.y)
            petalCtx.rotate(by: .degrees(Double(k) * 360 / Double(petals)))
            let petal = Path(ellipseIn: CGRect(x: -petalWidth / 2, y: -petalLength, width: petalWidth, height: petalLength))
            petalCtx.fill(petal, with: .color(color))
        }
        ctx.fill(circle(center, box.width * 0.09), with: .color(TileInk.gold))
        ctx.stroke(circle(center, box.width * 0.09), with: .color(TileInk.face), lineWidth: 1)
    }
}

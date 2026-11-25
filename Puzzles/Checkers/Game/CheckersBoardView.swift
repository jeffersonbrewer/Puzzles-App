import SwiftUI
import UIKit

/// Colors for the checkers board. The dark squares follow the theme color.
enum CheckersColors {
    static let lightSquare = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.30, alpha: 1)
            : UIColor(red: 0.97, green: 0.95, blue: 0.90, alpha: 1)
    })

    static let playerPiece = Color(red: 0.82, green: 0.20, blue: 0.20)
    static let playerRim = Color(red: 0.55, green: 0.08, blue: 0.10)

    static let computerPiece = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.13, alpha: 1) : UIColor(white: 0.17, alpha: 1)
    })
    static let computerRim = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.55, alpha: 1) : UIColor(white: 0.02, alpha: 1)
    })

    static let crown = Color(red: 1.0, green: 0.80, blue: 0.25)
    static let lastMove = Color(red: 0.98, green: 0.85, blue: 0.30).opacity(0.45)
}

/// Draws a board and reports taps. Used by games and lessons alike.
struct CheckersBoardView: View {
    @Environment(\.palette) private var palette

    let board: Checkers
    var selectedPath: [Int] = []
    var targets: Set<Int> = []
    var lastMove: CheckersMove?
    var hint: CheckersMove?
    var flash: Set<Int> = []
    /// Pieces given a soft outline because they can move.
    var movable: Set<Int> = []
    /// Letters a-h along the bottom and numbers 1-8 up the left side.
    var showCoordinates = false
    var onTap: (Int) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 8
            ZStack(alignment: .topLeading) {
                squares(cell: cell)
                markers(cell: cell)
                pieces(cell: cell)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.accent.opacity(0.6), lineWidth: 2))
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { point in
                let r = Int(point.y / cell), c = Int(point.x / cell)
                if let s = Checkers.square(r, c), Checkers.isDark(s) { onTap(s) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func origin(_ s: Int, cell: CGFloat) -> CGPoint {
        CGPoint(x: CGFloat(Checkers.column(s)) * cell, y: CGFloat(Checkers.row(s)) * cell)
    }

    private func center(_ s: Int, cell: CGFloat) -> CGPoint {
        let o = origin(s, cell: cell)
        return CGPoint(x: o.x + cell / 2, y: o.y + cell / 2)
    }

    private func squares(cell: CGFloat) -> some View {
        Canvas { context, _ in
            for s in 0..<64 {
                let rect = CGRect(origin: origin(s, cell: cell), size: CGSize(width: cell, height: cell))
                context.fill(Path(rect), with: .color(Checkers.isDark(s) ? palette.accent : CheckersColors.lightSquare))
            }
            // Soften the theme color a little so the pieces stand out.
            for s in 0..<64 where Checkers.isDark(s) {
                let rect = CGRect(origin: origin(s, cell: cell), size: CGSize(width: cell, height: cell))
                context.fill(Path(rect), with: .color(Color.black.opacity(0.12)))
            }
            guard showCoordinates else { return }
            let font = Font.system(size: max(8, cell * 0.17), weight: .semibold)
            for i in 0..<8 {
                let onDark = { (s: Int) -> Color in Checkers.isDark(s) ? .white.opacity(0.85) : .secondary }
                let rank = Text("\(8 - i)").font(font).foregroundColor(onDark(i * 8))
                context.draw(rank, at: CGPoint(x: 2, y: CGFloat(i) * cell + 2), anchor: .topLeading)
                let file = Text(String(Array("abcdefgh")[i])).font(font).foregroundColor(onDark(56 + i))
                context.draw(file, at: CGPoint(x: CGFloat(i + 1) * cell - 2, y: 8 * cell - 1), anchor: .bottomTrailing)
            }
        }
    }

    @ViewBuilder
    private func markers(cell: CGFloat) -> some View {
        let last = Set(lastMove?.path ?? [])
        ForEach(Array(last), id: \.self) { s in
            Rectangle()
                .fill(CheckersColors.lastMove)
                .frame(width: cell, height: cell)
                .offset(x: origin(s, cell: cell).x, y: origin(s, cell: cell).y)
        }
        ForEach(Array(Set(selectedPath)), id: \.self) { s in
            Rectangle()
                .fill(Theme.patternCell)
                .frame(width: cell, height: cell)
                .offset(x: origin(s, cell: cell).x, y: origin(s, cell: cell).y)
        }
        if let hint {
            ForEach(Array(Set(hint.path)), id: \.self) { s in
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Theme.patternCandidate, lineWidth: 3)
                    .frame(width: cell - 3, height: cell - 3)
                    .offset(x: origin(s, cell: cell).x + 1.5, y: origin(s, cell: cell).y + 1.5)
            }
        }
        ForEach(Array(targets), id: \.self) { s in
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: cell * 0.30, height: cell * 0.30)
                .shadow(color: .black.opacity(0.25), radius: 1)
                .position(center(s, cell: cell))
        }
    }

    private func pieces(cell: CGFloat) -> some View {
        let placed = (0..<64).compactMap { s in board.squares[s].map { PlacedPiece(square: s, piece: $0) } }
        return ForEach(placed) { item in
            PieceView(
                piece: item.piece,
                size: cell * 0.80,
                isSelected: selectedPath.first == item.square,
                isFlashing: flash.contains(item.square),
                isMovable: movable.contains(item.square)
            )
            .position(center(item.square, cell: cell))
            .transition(.opacity.combined(with: .scale(scale: 0.6)))
            .allowsHitTesting(false)
        }
    }
}

private struct PlacedPiece: Identifiable {
    let square: Int
    let piece: CheckersPiece
    var id: Int { piece.id }
}

struct PieceView: View {
    let piece: CheckersPiece
    let size: CGFloat
    var isSelected = false
    var isFlashing = false
    var isMovable = false

    private var fill: Color { piece.side == .player ? CheckersColors.playerPiece : CheckersColors.computerPiece }
    private var rim: Color { piece.side == .player ? CheckersColors.playerRim : CheckersColors.computerRim }

    var body: some View {
        ZStack {
            Circle()
                .fill(fill.gradient)
                .shadow(color: .black.opacity(0.35), radius: size * 0.04, y: size * 0.04)
            Circle()
                .stroke(rim, lineWidth: size * 0.06)
            Circle()
                .stroke(rim.opacity(0.7), lineWidth: size * 0.03)
                .padding(size * 0.17)
            if piece.isKing {
                Image(systemName: "crown.fill")
                    .font(.system(size: size * 0.40, weight: .bold))
                    .foregroundStyle(CheckersColors.crown)
                    .shadow(color: .black.opacity(0.4), radius: 1)
            }
            if isSelected {
                Circle().stroke(Color.white, lineWidth: size * 0.08).padding(-size * 0.06)
            } else if isFlashing {
                Circle().stroke(Theme.wrongText, lineWidth: size * 0.08).padding(-size * 0.06)
            } else if isMovable {
                Circle().stroke(Color.white.opacity(0.55), lineWidth: size * 0.04).padding(-size * 0.04)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("\(piece.side == .player ? "Your" : "Computer's") \(piece.isKing ? "king" : "piece")")
    }
}

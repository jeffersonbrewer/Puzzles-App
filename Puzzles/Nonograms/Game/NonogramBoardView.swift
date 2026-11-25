import SwiftUI

/// Sizes for drawing a puzzle with its clues, fitted to the space available.
struct NonogramLayout {
    let puzzle: NonogramPuzzle
    let cell: CGFloat
    /// Width of the row clues on the left and height of the column clues on top.
    let clueWidth: CGFloat
    let clueHeight: CGFloat

    /// Each clue number takes this fraction of a square.
    static let slot: CGFloat = 0.62

    init(puzzle: NonogramPuzzle, size: CGSize) {
        self.puzzle = puzzle
        let rowSlots = CGFloat(max(1, puzzle.rowClues.map(\.count).max() ?? 1))
        let colSlots = CGFloat(max(1, puzzle.columnClues.map(\.count).max() ?? 1))
        let byWidth = size.width / (CGFloat(puzzle.width) + rowSlots * Self.slot + 0.3)
        let byHeight = size.height / (CGFloat(puzzle.height) + colSlots * Self.slot + 0.3)
        cell = max(8, floor(min(byWidth, byHeight, 64)))
        clueWidth = ceil(rowSlots * Self.slot * cell + cell * 0.3)
        clueHeight = ceil(colSlots * Self.slot * cell + cell * 0.3)
    }

    var gridSize: CGSize { CGSize(width: cell * CGFloat(puzzle.width), height: cell * CGFloat(puzzle.height)) }
    var totalSize: CGSize { CGSize(width: clueWidth + gridSize.width, height: clueHeight + gridSize.height) }

    func rect(_ i: Int) -> CGRect {
        CGRect(x: CGFloat(i % puzzle.width) * cell, y: CGFloat(i / puzzle.width) * cell, width: cell, height: cell)
    }

    /// The square at a point in grid coordinates, clamped to the grid.
    func index(at p: CGPoint) -> Int {
        let c = min(puzzle.width - 1, max(0, Int(p.x / cell)))
        let r = min(puzzle.height - 1, max(0, Int(p.y / cell)))
        return r * puzzle.width + c
    }
}

/// The squares of a puzzle (no clues), drawn from a list of marks. Shared by
/// the game board, the lessons and the picture thumbnails.
struct NonogramGridCanvas: View {
    @Environment(\.palette) private var palette
    let puzzle: NonogramPuzzle
    let cells: [NonoCell]
    let cell: CGFloat
    var showGrid = true
    var wrong: Set<Int> = []
    var shadedLines: Set<NonoLine> = []
    var hintFill: Set<Int> = []
    var hintCross: Set<Int> = []
    var hintMistakes: Set<Int> = []

    var body: some View {
        Canvas { ctx, _ in
            let w = puzzle.width, h = puzzle.height
            let full = CGRect(x: 0, y: 0, width: cell * CGFloat(w), height: cell * CGFloat(h))
            for line in shadedLines {
                let r: CGRect
                switch line {
                case .row(let row): r = CGRect(x: 0, y: CGFloat(row) * cell, width: full.width, height: cell)
                case .column(let col): r = CGRect(x: CGFloat(col) * cell, y: 0, width: cell, height: full.height)
                }
                ctx.fill(Path(r), with: .color(hintFill.isEmpty && hintCross.isEmpty ? palette.peerCell : Theme.houseShade))
            }
            let inset = showGrid ? max(1, cell * 0.06) : 0
            for i in cells.indices {
                let r = CGRect(x: CGFloat(i % w) * cell, y: CGFloat(i / w) * cell, width: cell, height: cell)
                if wrong.contains(i) || hintMistakes.contains(i) {
                    ctx.fill(Path(r), with: .color(Theme.wrongCell))
                }
                if hintFill.contains(i) {
                    ctx.fill(Path(roundedRect: r.insetBy(dx: inset, dy: inset), cornerRadius: cell * 0.12),
                             with: .color(Theme.placement.opacity(0.35)))
                }
                switch cells[i] {
                case .filled:
                    let color = wrong.contains(i) ? Theme.wrongText : palette.accent
                    ctx.fill(Path(roundedRect: r.insetBy(dx: inset, dy: inset), cornerRadius: showGrid ? cell * 0.12 : 0),
                             with: .color(color))
                case .crossed:
                    let color: Color = wrong.contains(i) ? Theme.wrongText : .secondary
                    ctx.stroke(cross(in: r), with: .color(color), lineWidth: max(1, cell * 0.07))
                case .unknown:
                    if hintCross.contains(i) {
                        ctx.stroke(cross(in: r), with: .color(Theme.elimination.opacity(0.75)), lineWidth: max(1, cell * 0.07))
                    }
                }
            }
            guard showGrid else { return }
            for c in 0...w {
                var p = Path()
                p.move(to: CGPoint(x: CGFloat(c) * cell, y: 0))
                p.addLine(to: CGPoint(x: CGFloat(c) * cell, y: full.height))
                let major = c % 5 == 0 || c == w
                ctx.stroke(p, with: .color(major ? Theme.boxLine : Theme.gridLine), lineWidth: major ? 1.5 : 0.5)
            }
            for r in 0...h {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: CGFloat(r) * cell))
                p.addLine(to: CGPoint(x: full.width, y: CGFloat(r) * cell))
                let major = r % 5 == 0 || r == h
                ctx.stroke(p, with: .color(major ? Theme.boxLine : Theme.gridLine), lineWidth: major ? 1.5 : 0.5)
            }
        }
        .frame(width: cell * CGFloat(puzzle.width), height: cell * CGFloat(puzzle.height))
    }

    private func cross(in r: CGRect) -> Path {
        let d = r.width * 0.28
        var p = Path()
        p.move(to: CGPoint(x: r.minX + d, y: r.minY + d))
        p.addLine(to: CGPoint(x: r.maxX - d, y: r.maxY - d))
        p.move(to: CGPoint(x: r.maxX - d, y: r.minY + d))
        p.addLine(to: CGPoint(x: r.minX + d, y: r.maxY - d))
        return p
    }
}

/// Row clues to the left of the grid, column clues above it.
struct NonogramClues: View {
    @Environment(\.palette) private var palette
    let layout: NonogramLayout
    var done: (NonoLine) -> Bool = { _ in false }
    var emphasized: Set<NonoLine> = []

    var body: some View {
        let puzzle = layout.puzzle
        let cell = layout.cell
        let font = Font.system(size: max(7, cell * 0.5), weight: .semibold, design: .rounded).monospacedDigit()
        ZStack(alignment: .topLeading) {
            // Column clues, bottom-aligned above each column.
            HStack(spacing: 0) {
                ForEach(0..<puzzle.width, id: \.self) { c in
                    let line = NonoLine.column(c)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        ForEach(Array(numbers(puzzle.columnClues[c]).enumerated()), id: \.offset) { _, n in
                            Text(n).frame(height: cell * NonogramLayout.slot)
                        }
                    }
                    .font(font)
                    .foregroundStyle(color(for: line))
                    .frame(width: cell, height: layout.clueHeight - 2)
                    .background(emphasized.contains(line) ? palette.sameDigit : .clear, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .offset(x: layout.clueWidth)

            // Row clues, right-aligned left of each row.
            VStack(spacing: 0) {
                ForEach(0..<puzzle.height, id: \.self) { r in
                    let line = NonoLine.row(r)
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        ForEach(Array(numbers(puzzle.rowClues[r]).enumerated()), id: \.offset) { _, n in
                            Text(n).frame(width: cell * NonogramLayout.slot)
                        }
                    }
                    .font(font)
                    .foregroundStyle(color(for: line))
                    .frame(width: layout.clueWidth - 2, height: cell)
                    .background(emphasized.contains(line) ? palette.sameDigit : .clear, in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .offset(y: layout.clueHeight)
        }
        .frame(width: layout.totalSize.width, height: layout.totalSize.height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func numbers(_ clue: [Int]) -> [String] {
        clue.isEmpty ? ["0"] : clue.map(String.init)
    }

    private func color(for line: NonoLine) -> Color {
        done(line) ? Color.secondary.opacity(0.45) : Color.primary
    }
}

/// The interactive board: clues plus the grid, which takes taps and drags.
struct NonogramBoardView: View {
    @ObservedObject var game: NonogramGame
    @AppStorage(NonogramSettingsKey.showMistakes) private var showMistakes = false

    var body: some View {
        GeometryReader { geo in
            let layout = NonogramLayout(puzzle: game.puzzle, size: geo.size)
            let active = activeLines
            ZStack(alignment: .topLeading) {
                NonogramClues(layout: layout, done: { game.isLineSatisfied($0) }, emphasized: active)
                NonogramGridCanvas(
                    puzzle: game.puzzle,
                    cells: game.cells,
                    cell: layout.cell,
                    showGrid: true,
                    wrong: showMistakes && !game.isComplete ? Set(game.cells.indices.filter { game.isWrong($0) }) : [],
                    shadedLines: active,
                    hintFill: game.hint?.fill ?? [],
                    hintCross: game.hint?.cross ?? [],
                    hintMistakes: game.hint?.mistakes ?? []
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            game.touch(layout.index(at: value.location))
                        }
                        .onEnded { _ in game.endStroke() }
                )
                .offset(x: layout.clueWidth, y: layout.clueHeight)
                .accessibilityLabel("Puzzle grid, \(game.puzzle.sizeName)")
            }
            .frame(width: layout.totalSize.width, height: layout.totalSize.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var activeLines: Set<NonoLine> {
        if let line = game.hint?.line { return [line] }
        guard let i = game.activeCell else { return [] }
        return [.row(i / game.puzzle.width), .column(i % game.puzzle.width)]
    }
}

/// A small picture of a solved puzzle.
struct NonogramThumbnail: View {
    let puzzle: NonogramPuzzle
    let size: CGFloat

    var body: some View {
        let cell = size / CGFloat(max(puzzle.width, puzzle.height))
        NonogramGridCanvas(
            puzzle: puzzle,
            cells: puzzle.solution.map { $0 ? .filled : .unknown },
            cell: cell,
            showGrid: false
        )
        .frame(width: size, height: size)
    }
}

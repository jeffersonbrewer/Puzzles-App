import SwiftUI

/// Draws a Sudoku grid. Used by both the game and the training lessons.
struct SudokuBoardView: View {
    @Environment(\.palette) private var palette
    let values: [Int]
    let givens: [Int]
    let notes: [UInt16]
    var selected: Int? = nil
    var wrongCells: Set<Int> = []
    var highlightPeers: Bool = true
    /// A technique to illustrate (pattern cells, houses and candidates).
    var step: LogicStep? = nil
    /// Also show what the step removes (red) or places (green).
    var showStepResult: Bool = false
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cell = size / 9
            ZStack(alignment: .topLeading) {
                ForEach(0..<81, id: \.self) { i in
                    cellView(i, size: cell)
                        .frame(width: cell, height: cell)
                        .contentShape(Rectangle())
                        .onTapGesture { onTap?(i) }
                        .offset(x: CGFloat(Sudoku.col(i)) * cell, y: CGFloat(Sudoku.row(i)) * cell)
                }
                gridLines(size: size)
                    .allowsHitTesting(false)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Derived state

    private var selectedDigit: Int? {
        guard let s = selected, values[s] != 0 else { return nil }
        return values[s]
    }

    private var eliminationSet: Set<CellDigit> {
        guard showStepResult, let step else { return [] }
        return Set(step.eliminations)
    }

    private var placementSet: Set<CellDigit> {
        guard showStepResult, let step else { return [] }
        return Set(step.placements)
    }

    private var patternSet: Set<CellDigit> {
        Set(step?.patternCandidates ?? [])
    }

    private func cellBackground(_ i: Int) -> Color {
        if i == selected { return palette.selectedCell }
        if let step {
            if step.patternCells.contains(i) { return Theme.patternCell }
            if step.houses.contains(where: { Sudoku.houses[$0].contains(i) }) { return Theme.houseShade }
            return .clear
        }
        if wrongCells.contains(i) { return Theme.wrongCell }
        if let d = selectedDigit, values[i] == d { return palette.sameDigit }
        if highlightPeers, let s = selected, Sudoku.sees(s, i) { return palette.peerCell }
        return .clear
    }

    // MARK: Cells

    @ViewBuilder
    private func cellView(_ i: Int, size: CGFloat) -> some View {
        ZStack {
            cellBackground(i)
            if values[i] != 0 {
                Text("\(values[i])")
                    .font(.system(size: size * 0.6, weight: givens[i] != 0 ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(valueColor(i))
            } else if notes[i] != 0 {
                notesGrid(i, size: size)
            }
        }
    }

    private func valueColor(_ i: Int) -> Color {
        if wrongCells.contains(i) { return Theme.wrongText }
        return givens[i] != 0 ? .primary : palette.accent
    }

    private func notesGrid(_ i: Int, size: CGFloat) -> some View {
        let mini = size / 3
        return VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let d = r * 3 + c + 1
                        noteView(cell: i, digit: d, present: notes[i].has(d), size: mini)
                            .frame(width: mini, height: mini)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func noteView(cell: Int, digit: Int, present: Bool, size: CGFloat) -> some View {
        if present {
            let key = CellDigit(cell: cell, digit: digit)
            let font = Font.system(size: size * 0.78, weight: .medium, design: .rounded)
            if eliminationSet.contains(key) {
                Text("\(digit)").font(font).foregroundStyle(.white)
                    .frame(width: size * 0.95, height: size * 0.95)
                    .background(Circle().fill(Theme.elimination))
                    .overlay(Rectangle().fill(.white).frame(height: 1).rotationEffect(.degrees(-45)))
            } else if placementSet.contains(key) {
                Text("\(digit)").font(font.weight(.bold)).foregroundStyle(.white)
                    .frame(width: size * 0.95, height: size * 0.95)
                    .background(Circle().fill(Theme.placement))
            } else if patternSet.contains(key) {
                Text("\(digit)").font(font.weight(.bold)).foregroundStyle(Theme.patternCandidate)
            } else if step == nil, selectedDigit == digit {
                Text("\(digit)").font(font.weight(.bold)).foregroundStyle(.white)
                    .frame(width: size * 0.95, height: size * 0.95)
                    .background(Circle().fill(palette.accent))
            } else {
                Text("\(digit)").font(font).foregroundStyle(.secondary)
            }
        } else {
            Color.clear
        }
    }

    // MARK: Lines

    private func gridLines(size: CGFloat) -> some View {
        let cell = size / 9
        return ZStack {
            Path { p in
                for k in 1..<9 where k % 3 != 0 {
                    let x = CGFloat(k) * cell
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size))
                    p.move(to: CGPoint(x: 0, y: x)); p.addLine(to: CGPoint(x: size, y: x))
                }
            }
            .stroke(Theme.gridLine, lineWidth: 0.5)
            Path { p in
                for k in [3, 6] {
                    let x = CGFloat(k) * cell
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size))
                    p.move(to: CGPoint(x: 0, y: x)); p.addLine(to: CGPoint(x: size, y: x))
                }
            }
            .stroke(Theme.boxLine, lineWidth: 1.5)
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.boxLine, lineWidth: 2)
        }
        .frame(width: size, height: size)
    }
}

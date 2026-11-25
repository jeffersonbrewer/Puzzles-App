import Foundation

/// What the player has marked in a square.
enum NonoCell: UInt8, Codable {
    case unknown, filled, crossed
}

/// A row or a column of the grid.
enum NonoLine: Hashable, Codable {
    case row(Int)
    case column(Int)

    var name: String {
        switch self {
        case .row(let r): return "Row \(r + 1)"
        case .column(let c): return "Column \(c + 1)"
        }
    }
}

/// A picture puzzle: the hidden picture plus the clues read from it.
struct NonogramPuzzle: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let width: Int
    let height: Int
    /// Row by row, true = filled.
    let solution: [Bool]
    let rowClues: [[Int]]
    let columnClues: [[Int]]

    init(id: String, name: String, width: Int, height: Int, solution: [Bool]) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.solution = solution
        rowClues = (0..<height).map { r in Self.clues((0..<width).map { solution[r * width + $0] }) }
        columnClues = (0..<width).map { c in Self.clues((0..<height).map { solution[$0 * width + c] }) }
    }

    /// `art` is one string per row: "#" filled, anything else empty.
    init(id: String, name: String, art: [String]) {
        let cells = art.flatMap { $0.map { $0 == "#" } }
        self.init(id: id, name: name, width: art.first?.count ?? 0, height: art.count, solution: cells)
    }

    var cellCount: Int { width * height }
    var sizeName: String { "\(width)×\(height)" }
    var isRandom: Bool { id.hasPrefix("random-") }

    /// The lengths of the runs of filled squares, in order. Empty means "0".
    static func clues(_ line: [Bool]) -> [Int] {
        var out: [Int] = []
        var run = 0
        for filled in line {
            if filled {
                run += 1
            } else if run > 0 {
                out.append(run)
                run = 0
            }
        }
        if run > 0 { out.append(run) }
        return out
    }

    func clues(for line: NonoLine) -> [Int] {
        switch line {
        case .row(let r): return rowClues[r]
        case .column(let c): return columnClues[c]
        }
    }

    /// Grid indices of a line's squares, in order.
    func indices(of line: NonoLine) -> [Int] {
        switch line {
        case .row(let r): return (0..<width).map { r * width + $0 }
        case .column(let c): return (0..<height).map { $0 * width + c }
        }
    }

    var allLines: [NonoLine] {
        (0..<height).map { NonoLine.row($0) } + (0..<width).map { NonoLine.column($0) }
    }
}

/// Works out everything that one row or column's clue forces, given what is
/// already marked in it.
enum LineSolver {
    /// Returns the line with every forced square filled or crossed, or nil if
    /// the clue can't fit what is already marked.
    static func solve(clues: [Int], line: [NonoCell]) -> [NonoCell]? {
        let n = line.count, k = clues.count
        let canFill = line.map { $0 != .crossed }
        let canEmpty = line.map { $0 != .filled }

        // run[i]: how many squares from i on could be filled in a row.
        var run = [Int](repeating: 0, count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            run[i] = canFill[i] ? run[i + 1] + 1 : 0
        }

        // f[i][j]: the first i squares can hold the first j blocks.
        var f = [[Bool]](repeating: [Bool](repeating: false, count: k + 1), count: n + 1)
        f[0][0] = true
        if n > 0 {
            for i in 1...n {
                for j in 0...k {
                    var ok = canEmpty[i - 1] && f[i - 1][j]
                    if !ok && j >= 1 {
                        let len = clues[j - 1], s = i - len
                        if s >= 0 && run[s] >= len {
                            ok = j == 1 ? f[s][0] : (s >= 1 && canEmpty[s - 1] && f[s - 1][j - 1])
                        }
                    }
                    f[i][j] = ok
                }
            }
        }
        guard f[n][k] else { return nil }

        // b[i][j]: the squares from i on can hold blocks j and later.
        var b = [[Bool]](repeating: [Bool](repeating: false, count: k + 1), count: n + 2)
        b[n][k] = true
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: k, through: 0, by: -1) {
                var ok = canEmpty[i] && b[i + 1][j]
                if !ok && j < k {
                    let len = clues[j]
                    if run[i] >= len {
                        let e = i + len
                        ok = j == k - 1 ? b[e][k] : (e < n && canEmpty[e] && b[e + 1][j + 1])
                    }
                }
                b[i][j] = ok
            }
        }

        var mayEmpty = [Bool](repeating: false, count: n)
        var mayFill = [Bool](repeating: false, count: n)
        for x in 0..<n where canEmpty[x] {
            mayEmpty[x] = (0...k).contains { f[x][$0] && b[x + 1][$0] }
        }
        for j in 0..<k {
            let len = clues[j]
            guard len <= n else { continue }
            for s in 0...(n - len) where run[s] >= len {
                let left = j == 0 ? f[s][0] : (s >= 1 && canEmpty[s - 1] && f[s - 1][j])
                guard left else { continue }
                let e = s + len
                let right = j == k - 1 ? b[e][k] : (e < n && canEmpty[e] && b[e + 1][j + 1])
                if right {
                    for x in s..<e { mayFill[x] = true }
                }
            }
        }

        var out = line
        for x in 0..<n where out[x] == .unknown {
            if mayFill[x] && !mayEmpty[x] {
                out[x] = .filled
            } else if mayEmpty[x] && !mayFill[x] {
                out[x] = .crossed
            }
        }
        return out
    }
}

/// One line's worth of progress: the squares its clue forces.
struct NonoDeduction: Equatable {
    var line: NonoLine
    var fill: Set<Int> = []
    var cross: Set<Int> = []
}

enum NonogramSolver {
    /// The line where the most new squares can be worked out, if any.
    static func bestDeduction(_ puzzle: NonogramPuzzle, cells: [NonoCell]) -> NonoDeduction? {
        var best: NonoDeduction?
        for line in puzzle.allLines {
            let idx = puzzle.indices(of: line)
            let current = idx.map { cells[$0] }
            guard let solved = LineSolver.solve(clues: puzzle.clues(for: line), line: current) else { continue }
            var d = NonoDeduction(line: line)
            for (pos, i) in idx.enumerated() where current[pos] != solved[pos] {
                if solved[pos] == .filled { d.fill.insert(i) } else { d.cross.insert(i) }
            }
            let count = d.fill.count + d.cross.count
            if count > 0 && count > (best.map { $0.fill.count + $0.cross.count } ?? 0) {
                best = d
            }
        }
        return best
    }

    /// True if the clues can be solved one line at a time and lead to the
    /// picture, which means there is one answer and no guessing is needed.
    static func isLineSolvable(_ puzzle: NonogramPuzzle) -> Bool {
        var cells = [NonoCell](repeating: .unknown, count: puzzle.cellCount)
        var changed = true
        while changed {
            changed = false
            for line in puzzle.allLines {
                let idx = puzzle.indices(of: line)
                let current = idx.map { cells[$0] }
                guard let solved = LineSolver.solve(clues: puzzle.clues(for: line), line: current) else { return false }
                if solved != current {
                    for (pos, i) in idx.enumerated() { cells[i] = solved[pos] }
                    changed = true
                }
            }
        }
        return cells.indices.allSatisfy { cells[$0] == (puzzle.solution[$0] ? .filled : .crossed) }
    }

    /// A random pattern that can be solved without guessing.
    static func random(size: Int) -> NonogramPuzzle {
        let density = size <= 5 ? 0.6 : 0.62
        while true {
            let cells = (0..<(size * size)).map { _ in Double.random(in: 0..<1) < density }
            let puzzle = NonogramPuzzle(
                id: "random-\(UUID().uuidString)",
                name: "Random \(size)×\(size)",
                width: size,
                height: size,
                solution: cells
            )
            if isLineSolvable(puzzle) { return puzzle }
        }
    }
}

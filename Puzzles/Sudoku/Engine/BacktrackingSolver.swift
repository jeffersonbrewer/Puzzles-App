import Foundation

/// A fast brute-force solver used to verify uniqueness and to build full grids.
/// It is not used for hints; see `LogicSolver` for human-style reasoning.
final class BacktrackingSolver {
    private var values: [Int]
    private var rows = [UInt16](repeating: 0, count: 9)
    private var cols = [UInt16](repeating: 0, count: 9)
    private var boxes = [UInt16](repeating: 0, count: 9)
    private let limit: Int
    private let randomize: Bool
    private(set) var solutionCount = 0
    private(set) var firstSolution: [Int]?

    private init?(_ grid: [Int], limit: Int, randomize: Bool) {
        precondition(grid.count == 81)
        values = grid
        self.limit = limit
        self.randomize = randomize
        for i in 0..<81 where grid[i] != 0 {
            let b = Sudoku.bit(grid[i])
            let r = Sudoku.row(i), c = Sudoku.col(i), x = Sudoku.box(i)
            if rows[r] & b != 0 || cols[c] & b != 0 || boxes[x] & b != 0 { return nil }
            rows[r] |= b; cols[c] |= b; boxes[x] |= b
        }
    }

    /// Counts solutions, stopping once `limit` is reached.
    static func countSolutions(_ grid: [Int], limit: Int = 2) -> Int {
        guard let solver = BacktrackingSolver(grid, limit: limit, randomize: false) else { return 0 }
        solver.search()
        return solver.solutionCount
    }

    static func solve(_ grid: [Int]) -> [Int]? {
        guard let solver = BacktrackingSolver(grid, limit: 1, randomize: false) else { return nil }
        solver.search()
        return solver.firstSolution
    }

    /// A random, completely filled valid grid.
    static func randomFullGrid() -> [Int] {
        let solver = BacktrackingSolver([Int](repeating: 0, count: 81), limit: 1, randomize: true)!
        solver.search()
        return solver.firstSolution!
    }

    private func search() {
        var best = -1
        var bestMask: UInt16 = 0
        var bestCount = 10
        for i in 0..<81 where values[i] == 0 {
            let mask = Sudoku.allCandidates & ~(rows[Sudoku.row(i)] | cols[Sudoku.col(i)] | boxes[Sudoku.box(i)])
            let n = mask.nonzeroBitCount
            if n == 0 { return }
            if n < bestCount {
                best = i; bestMask = mask; bestCount = n
                if n == 1 { break }
            }
        }
        if best < 0 {
            solutionCount += 1
            if firstSolution == nil { firstSolution = values }
            return
        }
        var digits = bestMask.digits
        if randomize { digits.shuffle() }
        let r = Sudoku.row(best), c = Sudoku.col(best), x = Sudoku.box(best)
        for d in digits {
            let b = Sudoku.bit(d)
            values[best] = d
            rows[r] |= b; cols[c] |= b; boxes[x] |= b
            search()
            values[best] = 0
            rows[r] &= ~b; cols[c] &= ~b; boxes[x] &= ~b
            if solutionCount >= limit { return }
        }
    }
}

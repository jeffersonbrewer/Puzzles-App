import Foundation

enum CheckersDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var blurb: String {
        switch self {
        case .easy: return "Looks one move ahead and sometimes slips."
        case .medium: return "Sees simple tricks and won't give pieces away."
        case .hard: return "Thinks many moves ahead. A real challenge."
        }
    }
}

/// The computer opponent: alpha-beta search over the rules in `Checkers`.
enum CheckersAI {
    /// The move the computer plays for the side to move.
    static func chooseMove(_ board: Checkers, difficulty: CheckersDifficulty) -> CheckersMove? {
        let moves = board.legalMoves()
        guard moves.count > 1 else { return moves.first }
        switch difficulty {
        case .easy:
            // Every so often it simply plays something.
            if Double.random(in: 0..<1) < 0.3 { return moves.randomElement() }
            return pickAmongBest(board, moves: moves, depth: 2, slack: 30)
        case .medium:
            return pickAmongBest(board, moves: moves, depth: 4, slack: 8)
        case .hard:
            return deepSearch(board, maxDepth: 14, seconds: 1.2)
        }
    }

    /// A strong move for a hint.
    static func hint(_ board: Checkers) -> CheckersMove? {
        let moves = board.legalMoves()
        guard moves.count > 1 else { return moves.first }
        return deepSearch(board, maxDepth: 10, seconds: 0.6)
    }

    // MARK: - Search

    private static let win = 100_000

    /// Scores every move exactly and picks one at random from those close to the best.
    private static func pickAmongBest(_ board: Checkers, moves: [CheckersMove], depth: Int, slack: Int) -> CheckersMove? {
        var search = Search(deadline: .distantFuture)
        let scored = moves.map { m in
            (m, -search.negamax(board.applying(m), depth: depth - 1, alpha: -win - 1, beta: win + 1, ply: 1))
        }
        guard let best = scored.map(\.1).max() else { return nil }
        return scored.filter { $0.1 >= best - slack }.randomElement()?.0
    }

    /// Iterative deepening until the time runs out, keeping the last finished answer.
    private static func deepSearch(_ board: Checkers, maxDepth: Int, seconds: Double) -> CheckersMove? {
        var moves = board.legalMoves().shuffled()
        var search = Search(deadline: Date().addingTimeInterval(seconds))
        var best = moves[0]
        for depth in 1...maxDepth {
            var alpha = -win - 1
            var bestThisDepth: CheckersMove?
            var scores: [CheckersMove: Int] = [:]
            for m in moves {
                let score = -search.negamax(board.applying(m), depth: depth - 1, alpha: -win - 1, beta: -alpha, ply: 1)
                if search.aborted { break }
                scores[m] = score
                if score > alpha {
                    alpha = score
                    bestThisDepth = m
                }
            }
            if search.aborted { break }
            if let b = bestThisDepth { best = b }
            // A forced win was found; no need to look further.
            if alpha >= win - 200 { break }
            // Search the best moves first next time.
            moves.sort { (scores[$0] ?? -win) > (scores[$1] ?? -win) }
        }
        return best
    }

    private struct Search {
        let deadline: Date
        var nodes = 0
        var aborted = false

        mutating func negamax(_ board: Checkers, depth: Int, alpha: Int, beta: Int, ply: Int) -> Int {
            nodes += 1
            if nodes & 2047 == 0, Date() > deadline { aborted = true }
            if aborted { return 0 }
            if board.quietPlies >= Checkers.drawPlies { return 0 }

            let moves = board.legalMoves()
            if moves.isEmpty { return -(CheckersAI.win - ply) }
            // Keep looking through forced captures, so a trade isn't cut off halfway.
            let forced = moves[0].isCapture || moves.count == 1
            if depth <= 0 && (!forced || ply > 40) { return CheckersAI.evaluate(board) }
            let nextDepth = forced && depth <= 1 ? max(depth - 1, 0) : depth - 1

            var alpha = alpha
            var best = -CheckersAI.win - 1
            for m in ordered(moves) {
                let score = -negamax(board.applying(m), depth: nextDepth, alpha: -beta, beta: -alpha, ply: ply + 1)
                if aborted { return 0 }
                if score > best { best = score }
                if score > alpha { alpha = score }
                if alpha >= beta { break }
            }
            return best
        }

        /// Bigger captures first.
        private func ordered(_ moves: [CheckersMove]) -> [CheckersMove] {
            guard moves.count > 1, moves[0].isCapture else { return moves }
            return moves.sorted { $0.captures.count > $1.captures.count }
        }
    }

    // MARK: - Evaluation

    /// Score from the point of view of the side to move.
    static func evaluate(_ board: Checkers) -> Int {
        var material = [CheckersSide.player: 0, .computer: 0]
        var position = [CheckersSide.player: 0, .computer: 0]
        var men = [CheckersSide.player: 0, .computer: 0]

        for s in 0..<64 {
            guard let p = board.squares[s] else { continue }
            let r = Checkers.row(s), c = Checkers.column(s)
            if p.isKing {
                material[p.side]! += 150
                // Kings are strongest in the middle of the board.
                let distance = abs(2 * r - 7) + abs(2 * c - 7)
                position[p.side]! += (14 - distance) / 2
            } else {
                material[p.side]! += 100
                men[p.side]! += 1
                let advanced = p.side == .player ? 7 - r : r
                position[p.side]! += advanced * 3
                if r == p.side.homeRow { position[p.side]! += 6 }
                if (2...5).contains(c) && (3...4).contains(r) { position[p.side]! += 4 }
            }
        }

        let me = board.turn, them = board.turn.opponent
        var score = material[me]! - material[them]! + position[me]! - position[them]!

        // When ahead, trading down makes the extra piece count for more.
        let lead = material[me]! - material[them]!
        if abs(lead) >= 100 {
            let total = board.count(.player) + board.count(.computer)
            score += (lead > 0 ? 1 : -1) * (24 - total) * 6
        }

        // In an endgame of kings, the side ahead should close in.
        if men[me]! + men[them]! <= 2, lead != 0 {
            let chaser = lead > 0 ? me : them
            let closeness = kingCloseness(board, chaser: chaser)
            score += lead > 0 ? closeness : -closeness
        }
        return score
    }

    /// Higher when the chaser's kings are near the other side's pieces.
    private static func kingCloseness(_ board: Checkers, chaser: CheckersSide) -> Int {
        var kings: [Int] = [], targets: [Int] = []
        for s in 0..<64 {
            guard let p = board.squares[s] else { continue }
            if p.side == chaser && p.isKing { kings.append(s) } else if p.side != chaser { targets.append(s) }
        }
        guard !targets.isEmpty else { return 0 }
        var total = 0
        for k in kings {
            let nearest = targets.map { t in
                max(abs(Checkers.row(k) - Checkers.row(t)), abs(Checkers.column(k) - Checkers.column(t)))
            }.min() ?? 0
            total += 8 - nearest
        }
        return total * 2
    }
}

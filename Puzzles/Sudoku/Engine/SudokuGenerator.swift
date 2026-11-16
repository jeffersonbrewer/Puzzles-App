import Foundation

enum Difficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy, medium, hard, expert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .expert: return "Expert"
        }
    }

    var blurb: String {
        switch self {
        case .easy: return "Plenty of clues. Singles only."
        case .medium: return "Fewer clues. Still singles only."
        case .hard: return "Needs pairs, triples and pointing."
        case .expert: return "Needs X-Wings, Y-Wings and friends."
        }
    }

    /// Fewest clues to leave while removing.
    fileprivate var minimumClues: Int {
        switch self {
        case .easy: return 36
        default: return 17
        }
    }

    /// Which hardest-technique tiers are acceptable.
    fileprivate var acceptedTiers: ClosedRange<Int> {
        switch self {
        case .easy, .medium: return 0...0
        case .hard: return 1...2
        case .expert: return 3...3
        }
    }
}

struct SudokuPuzzle: Codable, Sendable {
    let givens: [Int]
    let solution: [Int]
    let difficulty: Difficulty
}

enum SudokuGenerator {
    /// Generates a puzzle with a unique solution that the logic solver can
    /// finish, matching the requested difficulty. Runs in roughly a second
    /// or less on a phone; call it off the main thread.
    static func generate(_ difficulty: Difficulty, maxAttempts: Int = 400) -> SudokuPuzzle {
        var fallback: (givens: [Int], solution: [Int], tier: Int)?
        for _ in 0..<maxAttempts {
            let (givens, solution) = makeMinimal(minimumClues: difficulty.minimumClues)
            guard let tier = LogicSolver.grade(givens) else { continue }
            if difficulty.acceptedTiers.contains(tier) {
                return SudokuPuzzle(givens: givens, solution: solution, difficulty: difficulty)
            }
            // Keep the closest miss in case we run out of attempts.
            let target = difficulty.acceptedTiers.lowerBound
            if fallback == nil || abs(tier - target) < abs(fallback!.tier - target) {
                fallback = (givens, solution, tier)
            }
        }
        if let f = fallback {
            return SudokuPuzzle(givens: f.givens, solution: f.solution, difficulty: difficulty)
        }
        let (givens, solution) = makeMinimal(minimumClues: 30)
        return SudokuPuzzle(givens: givens, solution: solution, difficulty: difficulty)
    }

    /// Fills a random grid, then removes clues in symmetric pairs while the
    /// solution stays unique.
    static func makeMinimal(minimumClues: Int) -> (givens: [Int], solution: [Int]) {
        let solution = BacktrackingSolver.randomFullGrid()
        var puzzle = solution
        var clues = 81
        for i in (0...40).shuffled() {
            let j = 80 - i
            let removing = i == j ? 1 : 2
            if clues - removing < minimumClues { continue }
            let a = puzzle[i], b = puzzle[j]
            puzzle[i] = 0
            puzzle[j] = 0
            if BacktrackingSolver.countSolutions(puzzle, limit: 2) == 1 {
                clues -= removing
            } else {
                puzzle[i] = a
                puzzle[j] = b
            }
        }
        return (puzzle, solution)
    }
}

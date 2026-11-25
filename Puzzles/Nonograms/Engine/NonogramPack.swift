import Foundation

/// The built-in picture sets, by size.
enum NonogramPack: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var puzzles: [NonogramPuzzle] {
        switch self {
        case .small: return NonogramLibrary.small
        case .medium: return NonogramLibrary.medium
        case .large: return NonogramLibrary.large
        }
    }

    var size: Int {
        switch self {
        case .small: return 5
        case .medium: return 10
        case .large: return 15
        }
    }

    var title: String { "\(size)×\(size)" }

    var blurb: String {
        switch self {
        case .small: return "Quick warm-ups. A good place to start."
        case .medium: return "The classic size. A few minutes each."
        case .large: return "Bigger pictures that take some planning."
        }
    }

    static func pack(containing puzzle: NonogramPuzzle) -> NonogramPack? {
        allCases.first { pack in pack.puzzles.contains { $0.id == puzzle.id } }
    }

    /// "10×10 · No. 4", or "Random 10×10".
    static func title(for puzzle: NonogramPuzzle) -> String {
        if let pack = pack(containing: puzzle), let n = pack.puzzles.firstIndex(where: { $0.id == puzzle.id }) {
            return "\(pack.title) · No. \(n + 1)"
        }
        return puzzle.name
    }

    /// The next unsolved picture after this one (wrapping around), or nil if
    /// every other picture in the set is solved.
    func nextUnsolved(after puzzle: NonogramPuzzle) -> NonogramPuzzle? {
        let solved = NonogramRecords.solved
        let start = puzzles.firstIndex { $0.id == puzzle.id } ?? -1
        for step in 1..<max(1, puzzles.count) {
            let p = puzzles[(start + step + puzzles.count) % puzzles.count]
            if !solved.contains(p.id) && p.id != puzzle.id { return p }
        }
        return nil
    }

    /// Whether there's a puzzle to offer after this one.
    static func hasNext(after puzzle: NonogramPuzzle) -> Bool {
        if puzzle.isRandom { return true }
        return pack(containing: puzzle)?.nextUnsolved(after: puzzle) != nil
    }

    /// A new random puzzle of the same size, or the set's next unsolved picture.
    static func next(after puzzle: NonogramPuzzle) -> NonogramPuzzle? {
        if puzzle.isRandom { return NonogramSolver.random(size: puzzle.width) }
        return pack(containing: puzzle)?.nextUnsolved(after: puzzle)
    }
}

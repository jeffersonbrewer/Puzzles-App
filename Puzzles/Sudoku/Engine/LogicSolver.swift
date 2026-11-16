import Foundation

/// Solving techniques, ordered from easiest to hardest.
enum Technique: String, CaseIterable, Codable, Identifiable {
    case hiddenSingle
    case nakedSingle
    case pointing
    case boxLine
    case nakedPair
    case hiddenPair
    case nakedTriple
    case xWing
    case yWing
    case xyzWing
    case swordfish

    var id: String { rawValue }

    /// 0 = basic, 1 = intermediate, 2 = hard, 3 = expert.
    var tier: Int {
        switch self {
        case .hiddenSingle, .nakedSingle: return 0
        case .pointing, .boxLine, .nakedPair: return 1
        case .hiddenPair, .nakedTriple: return 2
        case .xWing, .yWing, .xyzWing, .swordfish: return 3
        }
    }

    var title: String {
        switch self {
        case .hiddenSingle: return "Hidden Single"
        case .nakedSingle: return "Naked Single"
        case .pointing: return "Pointing Pair"
        case .boxLine: return "Box/Line Reduction"
        case .nakedPair: return "Naked Pair"
        case .hiddenPair: return "Hidden Pair"
        case .nakedTriple: return "Naked Triple"
        case .xWing: return "X-Wing"
        case .yWing: return "Y-Wing"
        case .xyzWing: return "XYZ-Wing"
        case .swordfish: return "Swordfish"
        }
    }
}

/// One deduction: a technique plus what it lets you place or eliminate.
struct LogicStep {
    let technique: Technique
    var placements: [CellDigit] = []
    var eliminations: [CellDigit] = []
    /// Cells that form the pattern.
    var patternCells: [Int] = []
    /// Candidates inside the pattern that drive the deduction.
    var patternCandidates: [CellDigit] = []
    /// Houses (rows/columns/boxes) involved, for light shading.
    var houses: [Int] = []
    var explanation: String
}

/// Grid values plus pencil-mark candidates for every empty cell.
struct CandidateGrid {
    var values: [Int]
    var candidates: [UInt16]

    /// Builds full candidates from the placed values.
    init(values: [Int]) {
        self.values = values
        candidates = [UInt16](repeating: 0, count: 81)
        for i in 0..<81 where values[i] == 0 {
            var mask = Sudoku.allCandidates
            for p in Sudoku.peers[i] where values[p] != 0 {
                mask &= ~Sudoku.bit(values[p])
            }
            candidates[i] = mask
        }
    }

    init(values: [Int], candidates: [UInt16]) {
        self.values = values
        self.candidates = candidates
    }

    var isSolved: Bool { !values.contains(0) }

    mutating func place(_ cell: Int, _ digit: Int) {
        values[cell] = digit
        candidates[cell] = 0
        let b = Sudoku.bit(digit)
        for p in Sudoku.peers[cell] { candidates[p] &= ~b }
    }

    mutating func eliminate(_ cell: Int, _ digit: Int) {
        candidates[cell] &= ~Sudoku.bit(digit)
    }

    mutating func apply(_ step: LogicStep) {
        for p in step.placements { place(p.cell, p.digit) }
        for e in step.eliminations { eliminate(e.cell, e.digit) }
    }

    func cells(in house: Int, with digit: Int) -> [Int] {
        Sudoku.houses[house].filter { candidates[$0].has(digit) }
    }
}

/// Human-style solver used for grading difficulty, hints and training.
enum LogicSolver {
    static let boxesFirst: [Int] = Array(18..<27) + Array(0..<18)

    /// The easiest available deduction, or nil if none of the known techniques apply.
    static func nextStep(_ g: CandidateGrid) -> LogicStep? {
        for t in Technique.allCases {
            if let step = find(t, in: g) { return step }
        }
        return nil
    }

    static func find(_ technique: Technique, in g: CandidateGrid) -> LogicStep? {
        switch technique {
        case .hiddenSingle: return hiddenSingle(g)
        case .nakedSingle: return nakedSingle(g)
        case .pointing: return pointing(g)
        case .boxLine: return boxLine(g)
        case .nakedPair: return nakedSubset(g, size: 2)
        case .hiddenPair: return hiddenPair(g)
        case .nakedTriple: return nakedSubset(g, size: 3)
        case .xWing: return fish(g, size: 2)
        case .yWing: return yWing(g)
        case .xyzWing: return xyzWing(g)
        case .swordfish: return fish(g, size: 3)
        }
    }

    /// Hardest tier needed to solve, or nil if the logic solver gets stuck.
    static func grade(_ givens: [Int]) -> Int? {
        var g = CandidateGrid(values: givens)
        var hardest = 0
        while !g.isSolved {
            guard let step = nextStep(g) else { return nil }
            hardest = max(hardest, step.technique.tier)
            g.apply(step)
        }
        return hardest
    }

    // MARK: - Singles

    static func hiddenSingle(_ g: CandidateGrid) -> LogicStep? {
        for h in boxesFirst {
            for d in 1...9 {
                let cells = g.cells(in: h, with: d)
                if cells.count == 1 {
                    let cell = cells[0]
                    return LogicStep(
                        technique: .hiddenSingle,
                        placements: [CellDigit(cell: cell, digit: d)],
                        patternCells: [cell],
                        patternCandidates: [CellDigit(cell: cell, digit: d)],
                        houses: [h],
                        explanation: "In \(Sudoku.houseName(h)), the only cell that can still hold a \(d) is \(Sudoku.cellName(cell)). Every other cell in the \(Sudoku.houseKind(h)) is filled or already sees a \(d), so \(Sudoku.cellName(cell)) must be \(d)."
                    )
                }
            }
        }
        return nil
    }

    static func nakedSingle(_ g: CandidateGrid) -> LogicStep? {
        for i in 0..<81 where g.values[i] == 0 && g.candidates[i].count == 1 {
            let d = g.candidates[i].digits[0]
            return LogicStep(
                technique: .nakedSingle,
                placements: [CellDigit(cell: i, digit: d)],
                patternCells: [i],
                patternCandidates: [CellDigit(cell: i, digit: d)],
                houses: [Sudoku.rowHouse(i), Sudoku.colHouse(i), Sudoku.boxHouse(i)],
                explanation: "\(Sudoku.cellName(i)) has only one candidate left. Every other digit already appears in its row, column or box, so it must be \(d)."
            )
        }
        return nil
    }

    // MARK: - Locked candidates

    static func pointing(_ g: CandidateGrid) -> LogicStep? {
        for h in 18..<27 {
            for d in 1...9 {
                let cells = g.cells(in: h, with: d)
                guard cells.count >= 2 else { continue }
                var lines: [Int] = []
                if Set(cells.map(Sudoku.row)).count == 1 { lines.append(Sudoku.rowHouse(cells[0])) }
                if Set(cells.map(Sudoku.col)).count == 1 { lines.append(Sudoku.colHouse(cells[0])) }
                for line in lines {
                    let elim = Sudoku.houses[line]
                        .filter { !cells.contains($0) && g.candidates[$0].has(d) }
                        .map { CellDigit(cell: $0, digit: d) }
                    if !elim.isEmpty {
                        return LogicStep(
                            technique: .pointing,
                            eliminations: elim,
                            patternCells: cells,
                            patternCandidates: cells.map { CellDigit(cell: $0, digit: d) },
                            houses: [h, line],
                            explanation: "In \(Sudoku.houseName(h)), every spot for \(d) (\(Sudoku.cellList(cells))) lies in \(Sudoku.houseName(line)). The box's \(d) has to be in \(Sudoku.houseName(line)), so no other cell of \(Sudoku.houseName(line)) can be \(d)."
                        )
                    }
                }
            }
        }
        return nil
    }

    static func boxLine(_ g: CandidateGrid) -> LogicStep? {
        for h in 0..<18 {
            for d in 1...9 {
                let cells = g.cells(in: h, with: d)
                guard cells.count >= 2, Set(cells.map(Sudoku.box)).count == 1 else { continue }
                let box = Sudoku.boxHouse(cells[0])
                let elim = Sudoku.houses[box]
                    .filter { !cells.contains($0) && g.candidates[$0].has(d) }
                    .map { CellDigit(cell: $0, digit: d) }
                if !elim.isEmpty {
                    return LogicStep(
                        technique: .boxLine,
                        eliminations: elim,
                        patternCells: cells,
                        patternCandidates: cells.map { CellDigit(cell: $0, digit: d) },
                        houses: [h, box],
                        explanation: "In \(Sudoku.houseName(h)), \(d) can only go in \(Sudoku.cellList(cells)), which are all inside \(Sudoku.houseName(box)). Whichever one it is, that box's \(d) is used up there, so \(d) can be removed from the rest of \(Sudoku.houseName(box))."
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Subsets

    static func nakedSubset(_ g: CandidateGrid, size n: Int) -> LogicStep? {
        let technique: Technique = n == 2 ? .nakedPair : .nakedTriple
        for h in 0..<27 {
            let empties = Sudoku.houses[h].filter { g.values[$0] == 0 }
            let pool = empties.filter { (2...n).contains(g.candidates[$0].count) }
            for combo in combinations(pool, n) {
                let mask = combo.reduce(UInt16(0)) { $0 | g.candidates[$1] }
                guard mask.count == n else { continue }
                var elim: [CellDigit] = []
                for j in empties where !combo.contains(j) {
                    for d in (g.candidates[j] & mask).digits { elim.append(CellDigit(cell: j, digit: d)) }
                }
                if !elim.isEmpty {
                    let digitText = Sudoku.listText(mask.digits.map { String($0) })
                    let count = n == 2 ? "two" : "three"
                    return LogicStep(
                        technique: technique,
                        eliminations: elim,
                        patternCells: combo,
                        patternCandidates: combo.flatMap { c in g.candidates[c].digits.map { CellDigit(cell: c, digit: $0) } },
                        houses: [h],
                        explanation: "In \(Sudoku.houseName(h)), the \(count) cells \(Sudoku.cellList(combo)) only contain the candidates \(digitText) between them. Those \(count) digits must fill those \(count) cells, so \(digitText) can be removed from every other cell in the \(Sudoku.houseKind(h))."
                    )
                }
            }
        }
        return nil
    }

    static func hiddenPair(_ g: CandidateGrid) -> LogicStep? {
        for h in 0..<27 {
            var positions: [Int: [Int]] = [:]
            for d in 1...9 { positions[d] = g.cells(in: h, with: d) }
            let pairDigits = (1...9).filter { positions[$0]!.count == 2 }
            for combo in combinations(pairDigits, 2) {
                let a = combo[0], b = combo[1]
                guard positions[a]! == positions[b]! else { continue }
                let cells = positions[a]!
                let keep = Sudoku.bit(a) | Sudoku.bit(b)
                var elim: [CellDigit] = []
                for c in cells {
                    for d in (g.candidates[c] & ~keep).digits { elim.append(CellDigit(cell: c, digit: d)) }
                }
                if !elim.isEmpty {
                    return LogicStep(
                        technique: .hiddenPair,
                        eliminations: elim,
                        patternCells: cells,
                        patternCandidates: cells.flatMap { [CellDigit(cell: $0, digit: a), CellDigit(cell: $0, digit: b)] },
                        houses: [h],
                        explanation: "In \(Sudoku.houseName(h)), the digits \(a) and \(b) can only go in \(Sudoku.cellList(cells)). Those two cells must hold \(a) and \(b), so every other candidate can be removed from them."
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Fish (X-Wing, Swordfish)

    static func fish(_ g: CandidateGrid, size n: Int) -> LogicStep? {
        let technique: Technique = n == 2 ? .xWing : .swordfish
        for d in 1...9 {
            for rowBased in [true, false] {
                let base = rowBased ? 0 : 9
                let other = rowBased ? 9 : 0
                var lines: [(index: Int, cells: [Int])] = []
                for li in 0..<9 {
                    let cells = g.cells(in: base + li, with: d)
                    if (2...n).contains(cells.count) { lines.append((li, cells)) }
                }
                for combo in combinations(lines.map { $0.index }, n) {
                    let chosen = lines.filter { combo.contains($0.index) }
                    let cells = chosen.flatMap { $0.cells }
                    let covers = Set(cells.map { rowBased ? Sudoku.col($0) : Sudoku.row($0) }).sorted()
                    guard covers.count == n else { continue }
                    let used = Set(combo)
                    var elim: [CellDigit] = []
                    for cv in covers {
                        for j in Sudoku.houses[other + cv] {
                            let lineOfJ = rowBased ? Sudoku.row(j) : Sudoku.col(j)
                            if !used.contains(lineOfJ) && g.candidates[j].has(d) {
                                elim.append(CellDigit(cell: j, digit: d))
                            }
                        }
                    }
                    if !elim.isEmpty {
                        let lineKind = rowBased ? "rows" : "columns"
                        let coverKind = rowBased ? "columns" : "rows"
                        let lineNames = Sudoku.listText(combo.map { String($0 + 1) })
                        let coverNames = Sudoku.listText(covers.map { String($0 + 1) })
                        let explanation: String
                        if n == 2 {
                            explanation = "In \(lineKind) \(lineNames), \(d) can only go in \(coverKind) \(coverNames). The two \(d)s for those \(lineKind) must sit on opposite corners of this rectangle, and either way they use up \(coverKind) \(coverNames). So no other cell in \(coverKind) \(coverNames) can be \(d)."
                        } else {
                            explanation = "In \(lineKind) \(lineNames), every spot for \(d) lies in \(coverKind) \(coverNames). Those three \(lineKind) need three \(d)s, and they must land in three different \(coverKind) from that set. That fills \(coverKind) \(coverNames) with \(d), so \(d) can be removed from the rest of them."
                        }
                        return LogicStep(
                            technique: technique,
                            eliminations: elim,
                            patternCells: cells,
                            patternCandidates: cells.map { CellDigit(cell: $0, digit: d) },
                            houses: combo.map { base + $0 },
                            explanation: explanation
                        )
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Wings

    static func yWing(_ g: CandidateGrid) -> LogicStep? {
        let bivalue = (0..<81).filter { g.candidates[$0].count == 2 }
        for pivot in bivalue {
            let pd = g.candidates[pivot].digits
            let a = pd[0], b = pd[1]
            // Try both orientations of the pivot's digits.
            for (x1, x2) in [(a, b), (b, a)] {
                for wing1 in bivalue where Sudoku.sees(pivot, wing1) {
                    let m1 = g.candidates[wing1]
                    guard m1.has(x1), !m1.has(x2) else { continue }
                    guard let z = m1.digits.first(where: { $0 != x1 }) else { continue }
                    let target = Sudoku.bit(x2) | Sudoku.bit(z)
                    for wing2 in bivalue where wing2 != wing1 && Sudoku.sees(pivot, wing2) && g.candidates[wing2] == target {
                        let common = Sudoku.peerSets[wing1].intersection(Sudoku.peerSets[wing2]).subtracting([pivot]).sorted()
                        let elim = common.filter { g.candidates[$0].has(z) }.map { CellDigit(cell: $0, digit: z) }
                        if !elim.isEmpty {
                            let p = Sudoku.cellName(pivot), w1 = Sudoku.cellName(wing1), w2 = Sudoku.cellName(wing2)
                            return LogicStep(
                                technique: .yWing,
                                eliminations: elim,
                                patternCells: [pivot, wing1, wing2],
                                patternCandidates: [pivot, wing1, wing2].flatMap { c in g.candidates[c].digits.map { CellDigit(cell: c, digit: $0) } },
                                houses: [],
                                explanation: "The pivot \(p) is either \(x1) or \(x2). If it is \(x1), then \(w1) (which sees it) must be \(z). If it is \(x2), then \(w2) must be \(z). Either way one of the wings is \(z), so any cell that sees both \(w1) and \(w2) cannot be \(z)."
                            )
                        }
                    }
                }
            }
        }
        return nil
    }

    static func xyzWing(_ g: CandidateGrid) -> LogicStep? {
        for pivot in 0..<81 where g.candidates[pivot].count == 3 {
            let pm = g.candidates[pivot]
            let wings = Sudoku.peers[pivot].filter { g.candidates[$0].count == 2 && g.candidates[$0] & pm == g.candidates[$0] }
            for combo in combinations(wings, 2) {
                let w1 = combo[0], w2 = combo[1]
                guard g.candidates[w1] != g.candidates[w2] else { continue }
                let common = g.candidates[w1] & g.candidates[w2]
                guard common.count == 1 else { continue }
                let z = common.digits[0]
                let seesAll = Sudoku.peerSets[pivot].intersection(Sudoku.peerSets[w1]).intersection(Sudoku.peerSets[w2]).sorted()
                let elim = seesAll.filter { g.candidates[$0].has(z) }.map { CellDigit(cell: $0, digit: z) }
                if !elim.isEmpty {
                    let digits = Sudoku.listText(pm.digits.map { String($0) })
                    return LogicStep(
                        technique: .xyzWing,
                        eliminations: elim,
                        patternCells: [pivot, w1, w2],
                        patternCandidates: [pivot, w1, w2].flatMap { c in g.candidates[c].digits.map { CellDigit(cell: c, digit: $0) } },
                        houses: [],
                        explanation: "The pivot \(Sudoku.cellName(pivot)) holds \(digits). The wings \(Sudoku.cellName(w1)) and \(Sudoku.cellName(w2)) each share \(z) with it. Whatever the pivot turns out to be, one of these three cells must be \(z). So any cell that sees all three cannot be \(z)."
                    )
                }
            }
        }
        return nil
    }
}

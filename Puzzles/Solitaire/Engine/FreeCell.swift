import Foundation

enum FreeCellPile: Hashable {
    case cell(Int)
    case foundation(Int)
    case tableau(Int)
}

/// Moves the last `count` cards of one pile onto another.
struct FreeCellMove: Equatable {
    var from: FreeCellPile
    var count: Int
    var to: FreeCellPile
}

/// The layout and rules of FreeCell. Pure value type with no UI in it.
/// Every card is face up; the top card of a pile is the last in its array.
struct FreeCell: Codable, Equatable {
    /// Four single-card holding spots.
    var cells: [Card?] = Array(repeating: nil, count: 4)
    /// One pile per suit, in `Suit` order.
    var foundations: [[Card]] = Array(repeating: [], count: 4)
    var tableau: [[Card]] = Array(repeating: [], count: 8)

    init() {}

    /// Deals a full deck across eight columns: four of seven and four of six.
    init(deck: [Card]) {
        for (i, card) in deck.enumerated() { tableau[i % 8].append(card) }
    }

    static func randomDeal() -> FreeCell { FreeCell(deck: Card.deck.shuffled()) }

    // MARK: - Queries

    var isWon: Bool { foundations.allSatisfy { $0.count == 13 } }

    var allCards: [Card] { cells.compactMap { $0 } + foundations.flatMap { $0 } + tableau.flatMap { $0 } }

    func cards(in pile: FreeCellPile) -> [Card] {
        switch pile {
        case .cell(let i): return cells[i].map { [$0] } ?? []
        case .foundation(let i): return foundations[i]
        case .tableau(let i): return tableau[i]
        }
    }

    var emptyCells: Int { cells.filter { $0 == nil }.count }
    var emptyColumns: Int { tableau.filter { $0.isEmpty }.count }

    /// How many cards can move together, using free cells and empty columns
    /// as stepping stones. Moving into an empty column leaves one fewer spare.
    func maxRun(toEmptyColumn: Bool) -> Int {
        let columns = emptyColumns - (toEmptyColumn ? 1 : 0)
        return (emptyCells + 1) << max(0, columns)
    }

    /// Length of the ordered run (down by one, alternating colors) at the
    /// bottom of a column.
    func runLength(_ column: Int) -> Int {
        let cards = tableau[column]
        guard !cards.isEmpty else { return 0 }
        var length = 1
        var i = cards.count - 1
        while i > 0, Self.stacks(cards[i], on: cards[i - 1]) {
            length += 1
            i -= 1
        }
        return length
    }

    static func stacks(_ card: Card, on below: Card) -> Bool {
        below.isRed != card.isRed && below.rank == card.rank + 1
    }

    /// How many cards move when the card at `index` of `pile` is picked up,
    /// or nil if that card can't be picked up.
    func pickupCount(_ pile: FreeCellPile, index: Int) -> Int? {
        let cards = cards(in: pile)
        guard cards.indices.contains(index) else { return nil }
        switch pile {
        case .cell, .foundation: return index == cards.count - 1 ? 1 : nil
        case .tableau(let i):
            let count = cards.count - index
            return count <= runLength(i) ? count : nil
        }
    }

    func isLegal(_ move: FreeCellMove) -> Bool {
        let source = cards(in: move.from)
        guard move.from != move.to, move.count > 0, move.count <= source.count,
              pickupCount(move.from, index: source.count - move.count) == move.count
        else { return false }
        let lead = source[source.count - move.count]
        switch move.to {
        case .cell(let i):
            return move.count == 1 && cells[i] == nil
        case .foundation(let i):
            return move.count == 1 && lead.suit.rawValue == i && lead.rank == foundations[i].count + 1
        case .tableau(let i):
            guard let top = tableau[i].last else { return move.count <= maxRun(toEmptyColumn: true) }
            return Self.stacks(lead, on: top) && move.count <= maxRun(toEmptyColumn: false)
        }
    }

    // MARK: - Changes

    mutating func apply(_ move: FreeCellMove) {
        let moving = Array(cards(in: move.from).suffix(move.count))
        switch move.from {
        case .cell(let i): cells[i] = nil
        case .foundation(let i): foundations[i].removeLast(move.count)
        case .tableau(let i): tableau[i].removeLast(move.count)
        }
        switch move.to {
        case .cell(let i): cells[i] = moving.first
        case .foundation(let i): foundations[i] += moving
        case .tableau(let i): tableau[i] += moving
        }
    }

    // MARK: - Choosing moves

    /// Where a tapped card should go: its foundation, then onto a column,
    /// then an empty column, then a free cell.
    func bestMove(from pile: FreeCellPile, index: Int) -> FreeCellMove? {
        guard let count = pickupCount(pile, index: index) else { return nil }
        if case .foundation = pile { return nil }
        let lead = cards(in: pile)[index]
        let home = FreeCellMove(from: pile, count: count, to: .foundation(lead.suit.rawValue))
        if isLegal(home) { return home }
        let filled = (0..<8).filter { !tableau[$0].isEmpty }
        for column in filled {
            let move = FreeCellMove(from: pile, count: count, to: .tableau(column))
            if isLegal(move) { return move }
        }
        // Moving a whole column into another empty column achieves nothing.
        let wholeColumn: Bool = { if case .tableau = pile { return index == 0 } else { return false } }()
        if !wholeColumn, let empty = (0..<8).first(where: { tableau[$0].isEmpty }) {
            let move = FreeCellMove(from: pile, count: count, to: .tableau(empty))
            if isLegal(move) { return move }
        }
        if case .tableau = pile, count == 1, let cell = cells.firstIndex(where: { $0 == nil }) {
            return FreeCellMove(from: pile, count: 1, to: .cell(cell))
        }
        return nil
    }

    /// A card that can go to its foundation without ever being needed in the
    /// tableau again: both cards of the other color one rank lower are home.
    func safeFoundationMove() -> FreeCellMove? {
        for pile in sources {
            guard let card = cards(in: pile).last else { continue }
            let move = FreeCellMove(from: pile, count: 1, to: .foundation(card.suit.rawValue))
            guard isLegal(move) else { continue }
            let otherColor = Suit.allCases.filter { $0.isRed != card.isRed }
            if card.rank <= 2 || otherColor.allSatisfy({ foundations[$0.rawValue].count >= card.rank - 1 }) {
                return move
            }
        }
        return nil
    }

    private var sources: [FreeCellPile] {
        (0..<4).map { FreeCellPile.cell($0) } + (0..<8).map { FreeCellPile.tableau($0) }
    }

    private func foundationMove() -> FreeCellMove? {
        for pile in sources {
            guard let card = cards(in: pile).last else { continue }
            let move = FreeCellMove(from: pile, count: 1, to: .foundation(card.suit.rawValue))
            if isLegal(move) { return move }
        }
        return nil
    }

    /// A useful next step, or nil when none of the simple ideas apply.
    func suggestion() -> FreeCellMove? {
        if let move = foundationMove() { return move }
        // Bring a card out of a free cell onto a column.
        for i in 0..<4 where cells[i] != nil {
            for column in 0..<8 where !tableau[column].isEmpty {
                let move = FreeCellMove(from: .cell(i), count: 1, to: .tableau(column))
                if isLegal(move) { return move }
            }
        }
        // Dig toward the lowest card still waiting in the tableau.
        if let dig = digMove() { return dig }
        // Join two runs together.
        for column in 0..<8 where !tableau[column].isEmpty {
            let start = tableau[column].count - runLength(column)
            for index in start..<tableau[column].count {
                guard let move = bestMove(from: .tableau(column), index: index),
                      case .tableau(let to) = move.to, !tableau[to].isEmpty else { continue }
                return move
            }
        }
        return nil
    }

    /// Moves the run covering the lowest buried card somewhere useful.
    private func digMove() -> FreeCellMove? {
        var best: (rank: Int, column: Int, index: Int)?
        for column in 0..<8 {
            let cards = tableau[column]
            for (index, card) in cards.enumerated() where index < cards.count - 1 {
                if best == nil || card.rank < best!.rank { best = (card.rank, column, index) }
            }
        }
        guard let best else { return nil }
        let cards = tableau[best.column]
        let runStart = cards.count - runLength(best.column)
        let pickFrom = max(runStart, best.index + 1)
        guard let move = bestMove(from: .tableau(best.column), index: pickFrom) else { return nil }
        // Only suggest parking in a cell when it frees the card right away.
        if case .cell = move.to, pickFrom != cards.count - 1 { return nil }
        if case .cell = move.to, best.index != cards.count - 2 { return nil }
        return move
    }

    /// No card is out of order, so the rest is certain to play out.
    var canFinish: Bool {
        !isWon && (0..<8).allSatisfy { runLength($0) == tableau[$0].count }
    }

    /// One step of finishing automatically. Returns false if there is nothing to do.
    mutating func finishStep() -> Bool {
        // Lowest card first, so the cards fly home in order.
        let candidates = sources.compactMap { pile -> (FreeCellMove, Int)? in
            guard let card = cards(in: pile).last else { return nil }
            let move = FreeCellMove(from: pile, count: 1, to: .foundation(card.suit.rawValue))
            return isLegal(move) ? (move, card.rank) : nil
        }
        guard let move = candidates.min(by: { $0.1 < $1.1 })?.0 else { return false }
        apply(move)
        return true
    }
}

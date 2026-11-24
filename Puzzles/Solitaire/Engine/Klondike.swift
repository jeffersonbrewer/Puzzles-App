import Foundation

enum Pile: Hashable {
    case stock
    case waste
    case foundation(Int)
    case tableau(Int)
}

/// Moves the last `count` cards of one pile onto another.
struct KlondikeMove: Equatable {
    var from: Pile
    var count: Int
    var to: Pile
}

/// A tableau column. The first `hidden` cards are face down.
struct TableauColumn: Codable, Equatable {
    var cards: [Card] = []
    var hidden = 0
}

/// The layout and rules of Klondike. Pure value type with no UI in it.
/// The top card of every pile is the last one in its array.
struct Klondike: Codable, Equatable {
    var stock: [Card] = []
    var waste: [Card] = []
    /// One pile per suit, in `Suit` order.
    var foundations: [[Card]] = Array(repeating: [], count: 4)
    var tableau: [TableauColumn] = Array(repeating: TableauColumn(), count: 7)

    /// Deals a full deck: columns of 1 to 7 cards, the rest to the stock.
    init(deck: [Card]) {
        var rest = deck
        for column in 0..<7 {
            tableau[column].cards = Array(rest.suffix(column + 1))
            tableau[column].hidden = column
            rest.removeLast(column + 1)
        }
        stock = rest
    }

    static func randomDeal() -> Klondike { Klondike(deck: Card.deck.shuffled()) }

    // MARK: - Queries

    var isWon: Bool { foundations.allSatisfy { $0.count == 13 } }

    func cards(in pile: Pile) -> [Card] {
        switch pile {
        case .stock: return stock
        case .waste: return waste
        case .foundation(let i): return foundations[i]
        case .tableau(let i): return tableau[i].cards
        }
    }

    /// How many cards move when the card at `index` of `pile` is picked up,
    /// or nil if that card can't be picked up.
    func pickupCount(_ pile: Pile, index: Int) -> Int? {
        let cards = cards(in: pile)
        guard cards.indices.contains(index) else { return nil }
        switch pile {
        case .stock: return nil
        case .waste, .foundation: return index == cards.count - 1 ? 1 : nil
        case .tableau(let i): return index >= tableau[i].hidden ? cards.count - index : nil
        }
    }

    func isLegal(_ move: KlondikeMove) -> Bool {
        let source = cards(in: move.from)
        guard move.from != move.to, move.count > 0, move.count <= source.count,
              pickupCount(move.from, index: source.count - move.count) == move.count
        else { return false }
        let lead = source[source.count - move.count]
        switch move.to {
        case .stock, .waste:
            return false
        case .foundation(let i):
            return move.count == 1 && lead.suit.rawValue == i && lead.rank == foundations[i].count + 1
        case .tableau(let i):
            guard let top = tableau[i].cards.last else { return lead.rank == 13 }
            return top.isRed != lead.isRed && top.rank == lead.rank + 1
        }
    }

    // MARK: - Changes

    /// Performs a legal move and turns over the card it uncovers.
    mutating func apply(_ move: KlondikeMove) {
        let moving = Array(cards(in: move.from).suffix(move.count))
        switch move.from {
        case .stock: stock.removeLast(move.count)
        case .waste: waste.removeLast(move.count)
        case .foundation(let i): foundations[i].removeLast(move.count)
        case .tableau(let i):
            tableau[i].cards.removeLast(move.count)
            if tableau[i].hidden > 0, tableau[i].hidden == tableau[i].cards.count { tableau[i].hidden -= 1 }
        }
        switch move.to {
        case .stock: stock += moving
        case .waste: waste += moving
        case .foundation(let i): foundations[i] += moving
        case .tableau(let i): tableau[i].cards += moving
        }
    }

    var canDraw: Bool { !stock.isEmpty || !waste.isEmpty }

    /// Turns over up to `count` stock cards, or recycles the waste when the
    /// stock is empty.
    mutating func draw(_ count: Int) {
        if stock.isEmpty {
            stock = waste.reversed()
            waste = []
        } else {
            for _ in 0..<min(count, stock.count) { waste.append(stock.removeLast()) }
        }
    }

    // MARK: - Choosing moves

    /// Where a tapped card should go: its foundation, then a column with
    /// cards, then an empty column.
    func bestMove(from pile: Pile, index: Int) -> KlondikeMove? {
        guard let count = pickupCount(pile, index: index) else { return nil }
        if case .foundation = pile { return nil }
        let lead = cards(in: pile)[index]
        let home = KlondikeMove(from: pile, count: count, to: .foundation(lead.suit.rawValue))
        if isLegal(home) { return home }
        // Moving a king between empty columns achieves nothing.
        if case .tableau = pile, lead.rank == 13, index == 0 { return nil }
        let columns = (0..<7).filter { !tableau[$0].cards.isEmpty } + (0..<7).filter { tableau[$0].cards.isEmpty }
        return columns.lazy
            .map { KlondikeMove(from: pile, count: count, to: .tableau($0)) }
            .first { isLegal($0) }
    }

    private func foundationMove() -> KlondikeMove? {
        let sources: [Pile] = (0..<7).map { Pile.tableau($0) } + [.waste]
        for pile in sources {
            guard let top = cards(in: pile).last else { continue }
            let move = KlondikeMove(from: pile, count: 1, to: .foundation(top.suit.rawValue))
            if isLegal(move) { return move }
        }
        return nil
    }

    enum Suggestion: Equatable {
        case move(KlondikeMove)
        case draw
    }

    /// A useful next step, or nil when none of the simple ideas apply.
    func suggestion(drawCount: Int) -> Suggestion? {
        if let move = foundationMove() { return .move(move) }
        // Turn over a face-down card, or empty a column when a king needs it.
        for i in (0..<7).sorted(by: { tableau[$0].hidden > tableau[$1].hidden }) {
            let column = tableau[i]
            guard !column.cards.isEmpty else { continue }
            if column.hidden == 0, !kingNeedsColumn { continue }
            if let move = bestMove(from: .tableau(i), index: column.hidden) { return .move(move) }
        }
        if !waste.isEmpty, let move = bestMove(from: .waste, index: waste.count - 1) { return .move(move) }
        if let move = uncoveringMove() { return .move(move) }
        return drawHelps(drawCount) ? .draw : nil
    }

    /// A king that could use an empty column.
    private var kingNeedsColumn: Bool {
        waste.last?.rank == 13 || tableau.contains { $0.hidden > 0 && $0.cards[$0.hidden].rank == 13 }
    }

    /// Moves part of a run so the card underneath can go to its foundation.
    private func uncoveringMove() -> KlondikeMove? {
        for i in 0..<7 {
            let column = tableau[i]
            for index in column.cards.indices where index > column.hidden {
                let under = column.cards[index - 1]
                guard foundations[under.suit.rawValue].count == under.rank - 1 else { continue }
                if let move = bestMove(from: .tableau(i), index: index) { return move }
            }
        }
        return nil
    }

    /// True if one trip through the stock turns up a playable card.
    private func drawHelps(_ drawCount: Int) -> Bool {
        var trial = self
        var recycled = false
        while trial.canDraw {
            if trial.stock.isEmpty {
                if recycled { return false }
                recycled = true
            }
            trial.draw(drawCount)
            if !trial.waste.isEmpty, trial.bestMove(from: .waste, index: trial.waste.count - 1) != nil { return true }
        }
        return false
    }

    /// Every card is face up, so the rest is certain to play out. (With draw
    /// three the stock has to be used up first to be certain.)
    func canFinish(drawCount: Int) -> Bool {
        !isWon && tableau.allSatisfy { $0.hidden == 0 } && (drawCount == 1 || !canDraw)
    }

    /// One step of finishing automatically. Returns false if there is nothing to do.
    mutating func finishStep() -> Bool {
        if let move = foundationMove() {
            apply(move)
            return true
        }
        guard canDraw else { return false }
        draw(1)
        return true
    }
}

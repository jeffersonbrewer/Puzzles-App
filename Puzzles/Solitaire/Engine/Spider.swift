import Foundation

/// One of Spider's 104 cards. Spider uses two decks, and with one or two
/// suits the same face repeats up to eight times, so each card gets its own
/// `id` (0..<104) apart from the face it shows.
struct SpiderCard: Hashable, Identifiable, Codable {
    let id: Int
    let face: Card

    var rank: Int { face.rank }
    var suit: Suit { face.suit }
    var name: String { face.name }

    /// The 104 cards for 1, 2 or 4 suits.
    static func deck(suits: Int) -> [SpiderCard] {
        let used: [Suit] = suits == 1 ? [.spades] : suits == 2 ? [.spades, .hearts] : Suit.allCases
        return (0..<104).map { id in
            let suit = used[(id / 13) % used.count]
            return SpiderCard(id: id, face: Card(suit, id % 13 + 1))
        }
    }
}

enum SpiderPile: Hashable {
    case stock
    /// Completed runs, filled in order.
    case foundation(Int)
    case tableau(Int)
}

/// Moves the last `count` cards of one column onto another.
struct SpiderMove: Equatable {
    var from: Int
    var count: Int
    var to: Int
}

/// A column. The first `hidden` cards are face down.
struct SpiderColumn: Codable, Equatable {
    var cards: [SpiderCard] = []
    var hidden = 0
}

/// The layout and rules of Spider. Pure value type with no UI in it.
struct Spider: Codable, Equatable {
    var suits: Int
    var stock: [SpiderCard] = []
    /// Each completed run, in the order they were finished, ace first.
    var completed: [[SpiderCard]] = []
    var tableau: [SpiderColumn] = Array(repeating: SpiderColumn(), count: 10)

    init(suits: Int) { self.suits = suits }

    /// Deals 54 cards (six to the first four columns, five to the rest)
    /// with only the bottom card of each face up. The other 50 are the stock.
    init(suits: Int, deck: [SpiderCard]) {
        self.suits = suits
        var rest = deck
        for column in 0..<10 {
            let count = column < 4 ? 6 : 5
            tableau[column].cards = Array(rest.suffix(count))
            tableau[column].hidden = count - 1
            rest.removeLast(count)
        }
        stock = rest
    }

    static func randomDeal(suits: Int) -> Spider {
        Spider(suits: suits, deck: SpiderCard.deck(suits: suits).shuffled())
    }

    // MARK: - Queries

    var isWon: Bool { completed.count == 8 || (stock.isEmpty && tableau.allSatisfy { $0.cards.isEmpty }) }

    var allCards: [SpiderCard] { stock + completed.flatMap { $0 } + tableau.flatMap(\.cards) }

    func cards(in pile: SpiderPile) -> [SpiderCard] {
        switch pile {
        case .stock: return stock
        case .foundation(let i): return completed.indices.contains(i) ? completed[i] : []
        case .tableau(let i): return tableau[i].cards
        }
    }

    /// Length of the same-suit run (down by one) at the bottom of a column.
    func runLength(_ column: Int) -> Int {
        let col = tableau[column]
        guard !col.cards.isEmpty else { return 0 }
        var length = 1
        var i = col.cards.count - 1
        while i > col.hidden, Self.follows(col.cards[i], col.cards[i - 1]) {
            length += 1
            i -= 1
        }
        return length
    }

    /// `card` sits on `below` as part of a movable run.
    static func follows(_ card: SpiderCard, _ below: SpiderCard) -> Bool {
        card.suit == below.suit && below.rank == card.rank + 1
    }

    /// How many cards move when the card at `index` of a column is picked up,
    /// or nil if that card can't be picked up.
    func pickupCount(_ column: Int, index: Int) -> Int? {
        let col = tableau[column]
        guard col.cards.indices.contains(index), index >= col.hidden else { return nil }
        let count = col.cards.count - index
        return count <= runLength(column) ? count : nil
    }

    func isLegal(_ move: SpiderMove) -> Bool {
        guard move.from != move.to, tableau.indices.contains(move.from), tableau.indices.contains(move.to)
        else { return false }
        let source = tableau[move.from].cards
        guard move.count > 0, move.count <= source.count,
              pickupCount(move.from, index: source.count - move.count) == move.count
        else { return false }
        let lead = source[source.count - move.count]
        guard let top = tableau[move.to].cards.last else { return true }
        return top.rank == lead.rank + 1
    }

    /// The stock deals one card to every column, and only when none is empty.
    var canDeal: Bool { !stock.isEmpty && tableau.allSatisfy { !$0.cards.isEmpty } }

    // MARK: - Changes

    /// Performs a legal move, clears a finished run and turns over the card
    /// it uncovers.
    mutating func apply(_ move: SpiderMove) {
        let moving = Array(tableau[move.from].cards.suffix(move.count))
        tableau[move.from].cards.removeLast(move.count)
        tableau[move.to].cards += moving
        settle(move.to)
        settle(move.from)
    }

    mutating func deal() {
        for column in 0..<10 {
            guard let card = stock.popLast() else { break }
            tableau[column].cards.append(card)
        }
        for column in 0..<10 { settle(column) }
    }

    /// Clears a completed king-to-ace run and turns up a newly exposed card.
    private mutating func settle(_ column: Int) {
        if runLength(column) >= 13, tableau[column].cards.last?.rank == 1 {
            let run = Array(tableau[column].cards.suffix(13))
            tableau[column].cards.removeLast(13)
            // Stored ace first, so the king shows on top of the pile.
            completed.append(run.reversed())
        }
        let col = tableau[column]
        if col.hidden > 0, col.hidden >= col.cards.count {
            tableau[column].hidden = col.cards.count - 1
        }
        if tableau[column].hidden < 0 { tableau[column].hidden = 0 }
    }

    // MARK: - Choosing moves

    /// Where a tapped run should go: onto the same suit, then any suit, then
    /// an empty column.
    func bestMove(from column: Int, index: Int) -> SpiderMove? {
        guard let count = pickupCount(column, index: index) else { return nil }
        let lead = tableau[column].cards[index]
        let targets = (0..<10).filter { $0 != column && tableau[$0].cards.last?.rank == lead.rank + 1 }
        if let same = targets.first(where: { tableau[$0].cards.last?.suit == lead.suit }) {
            return SpiderMove(from: column, count: count, to: same)
        }
        if let any = targets.first { return SpiderMove(from: column, count: count, to: any) }
        // Moving a whole column into an empty one achieves nothing.
        if index > 0, let empty = (0..<10).first(where: { tableau[$0].cards.isEmpty }) {
            return SpiderMove(from: column, count: count, to: empty)
        }
        return nil
    }

    enum Suggestion: Equatable {
        case move(SpiderMove)
        case deal
    }

    /// A useful next step, or nil when none of the simple ideas apply.
    func suggestion() -> Suggestion? {
        var best: (move: SpiderMove, score: Int)?
        for column in 0..<10 where !tableau[column].cards.isEmpty {
            let col = tableau[column]
            let start = col.cards.count - runLength(column)
            let lead = col.cards[start]
            for to in 0..<10 where to != column {
                guard let top = tableau[to].cards.last, top.rank == lead.rank + 1 else { continue }
                let move = SpiderMove(from: column, count: col.cards.count - start, to: to)
                var score = 0
                if top.suit == lead.suit { score += 4 }
                if start == col.hidden, col.hidden > 0 { score += 3 }
                if start == 0 { score += 2 }
                // Breaking a same-suit pair to land on another suit gains nothing.
                if start > col.hidden, Self.follows(lead, col.cards[start - 1]) { continue }
                if start > col.hidden, top.suit != lead.suit,
                   col.cards[start - 1].rank == lead.rank + 1 { continue }
                if score == 0, start > col.hidden { continue }
                if best == nil || score > best!.score { best = (move, score) }
            }
        }
        if let best { return .move(best.move) }
        // Fill an empty column with a run that uncovers a face-down card.
        if let empty = (0..<10).first(where: { tableau[$0].cards.isEmpty }) {
            for column in 0..<10 where tableau[column].hidden > 0 {
                let start = tableau[column].cards.count - runLength(column)
                if start == tableau[column].hidden {
                    return .move(SpiderMove(from: column, count: tableau[column].cards.count - start, to: empty))
                }
            }
        }
        return canDeal ? .deal : nil
    }
}

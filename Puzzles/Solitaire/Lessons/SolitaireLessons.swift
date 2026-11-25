import Foundation

/// The written part of a card game lesson, shown above the practice board.
struct LessonText {
    let title: String
    let summary: String
    /// Numbered points under "How it works".
    let rules: [String]
    /// Shown under "Tips".
    let tips: String
    /// Shown under the board before the player has moved.
    let prompt: String
    /// Shown once the practice goal is reached.
    let success: String
}

// MARK: - FreeCell

struct FreeCellLesson: Identifiable {
    let id: String
    let text: LessonText
    let board: FreeCell
    /// The moves that solve the practice, for "Show me".
    let solution: [FreeCellMove]
    let goal: (FreeCell) -> Bool

    static let all: [FreeCellLesson] = [basics, building, cells, runs]

    private static func makeBoard(_ columns: [[Card]], cells: [Card?] = [nil, nil, nil, nil], foundations: [Suit: Int] = [:]) -> FreeCell {
        var board = FreeCell()
        for (i, column) in columns.enumerated() { board.tableau[i] = column }
        board.cells = cells
        for (suit, count) in foundations {
            board.foundations[suit.rawValue] = (1...count).map { Card(suit, $0) }
        }
        return board
    }

    static let basics = FreeCellLesson(
        id: "freecell.goal",
        text: LessonText(
            title: "The goal",
            summary: "FreeCell starts with every card face up in eight columns. Move all 52 cards to the four foundations at the top right, one pile per suit, from ace up to king.",
            rules: [
                "Only the bottom card of each column can be played.",
                "A foundation takes the ace of its suit first, then the 2, then the 3, and so on up to the king.",
                "Tap a card to send it to the best spot, or drag it where you want it."
            ],
            tips: "Almost every FreeCell deal can be won, so it rewards thinking a few moves ahead. Aces and 2s buried deep in a column are the first problem to solve.",
            prompt: "Send the ace of hearts to its foundation, then the 2 of hearts after it.",
            success: "Both hearts are home. Cards play to the foundations in order, so the 3 of hearts would be next."
        ),
        board: makeBoard([
            [Card(.clubs, 9), Card(.hearts, 2), Card(.hearts, 1)],
            [Card(.spades, 5), Card(.diamonds, 8)],
            [Card(.clubs, 12), Card(.spades, 7)],
            [Card(.hearts, 11)],
            [Card(.diamonds, 4), Card(.clubs, 10)],
            [Card(.hearts, 6)],
            [Card(.clubs, 3), Card(.diamonds, 13)],
            [Card(.hearts, 9), Card(.spades, 6)]
        ]),
        solution: [
            FreeCellMove(from: .tableau(0), count: 1, to: .foundation(Suit.hearts.rawValue)),
            FreeCellMove(from: .tableau(0), count: 1, to: .foundation(Suit.hearts.rawValue))
        ],
        goal: { $0.foundations[Suit.hearts.rawValue].count >= 2 }
    )

    static let building = FreeCellLesson(
        id: "freecell.building",
        text: LessonText(
            title: "Building columns",
            summary: "A card can go on the bottom of a column when it is one rank lower and the opposite color, like a black 8 on a red 9. Building columns this way is how you dig out the cards you need.",
            rules: [
                "Red goes on black and black goes on red.",
                "Each card must be exactly one rank lower than the card it covers.",
                "Any card, or an ordered run, can go into an empty column."
            ],
            tips: "Before moving a card, ask what it uncovers. A move that frees an ace or a low card is usually worth more than one that only tidies a column.",
            prompt: "The ace of clubs is stuck under the 8 of clubs. Move the 8 somewhere it fits, then send the ace home.",
            success: "The 8 of clubs went on the red 9, which freed the ace. That is the basic rhythm of FreeCell."
        ),
        board: makeBoard([
            [Card(.spades, 13), Card(.diamonds, 5)],
            [Card(.spades, 5), Card(.diamonds, 8)],
            [Card(.clubs, 1), Card(.clubs, 8)],
            [Card(.hearts, 11)],
            [Card(.diamonds, 4), Card(.clubs, 10)],
            [Card(.hearts, 6)],
            [Card(.clubs, 3), Card(.diamonds, 13)],
            [Card(.spades, 6), Card(.hearts, 9)]
        ]),
        solution: [
            FreeCellMove(from: .tableau(2), count: 1, to: .tableau(7)),
            FreeCellMove(from: .tableau(2), count: 1, to: .foundation(Suit.clubs.rawValue))
        ],
        goal: { $0.foundations[Suit.clubs.rawValue].count >= 1 }
    )

    static let cells = FreeCellLesson(
        id: "freecell.cells",
        text: LessonText(
            title: "Free cells",
            summary: "The four free cells at the top left each hold one card. Any card can wait there, which lets you reach cards that have nowhere else to go.",
            rules: [
                "Each free cell holds a single card.",
                "A card in a free cell can go back to a column or to its foundation at any time.",
                "Tap a card that fits nowhere else and it goes to a free cell."
            ],
            tips: "Free cells fill up fast, and a full set leaves you stuck. Park a card only when you can see how it will come back out, and empty the cells again as soon as you can.",
            prompt: "The ace of spades is under the queen of hearts and the 4 of clubs, and neither fits on any column. Use the free cells to get the ace home.",
            success: "Two cards went to free cells and the ace went home. Now look for ways to bring those two back out."
        ),
        board: makeBoard([
            [Card(.diamonds, 7), Card(.spades, 1), Card(.hearts, 12), Card(.clubs, 4)],
            [Card(.spades, 5), Card(.diamonds, 8)],
            [Card(.clubs, 12), Card(.spades, 7)],
            [Card(.hearts, 11)],
            [Card(.diamonds, 4), Card(.clubs, 10)],
            [Card(.hearts, 6)],
            [Card(.clubs, 3), Card(.diamonds, 13)],
            [Card(.hearts, 9), Card(.spades, 6)]
        ]),
        solution: [
            FreeCellMove(from: .tableau(0), count: 1, to: .cell(0)),
            FreeCellMove(from: .tableau(0), count: 1, to: .cell(1)),
            FreeCellMove(from: .tableau(0), count: 1, to: .foundation(Suit.spades.rawValue))
        ],
        goal: { $0.foundations[Suit.spades.rawValue].count >= 1 }
    )

    static let runs = FreeCellLesson(
        id: "freecell.runs",
        text: LessonText(
            title: "Moving runs",
            summary: "An ordered run of cards can move together, as long as there is enough room to have moved them one at a time. The app works out the steps for you.",
            rules: [
                "With no empty columns you can move one card more than the number of empty free cells.",
                "Each empty column doubles that, so 2 empty cells and 1 empty column moves 6 cards.",
                "Moving a run into an empty column counts that column as used, so the limit is lower."
            ],
            tips: "Empty columns are the most valuable space in FreeCell, worth more than free cells. Try to empty one early and avoid filling it with a single card.",
            prompt: "Three free cells are empty, so you can move up to four cards at once. Move the run from the 10 of spades onto the jack of hearts, then send the 2 of diamonds home.",
            success: "Four cards moved in one go, which freed the 2 of diamonds. With one more card in a free cell, that run would have been too long to move."
        ),
        board: makeBoard(
            [
                [Card(.diamonds, 2), Card(.spades, 10), Card(.hearts, 9), Card(.clubs, 8), Card(.diamonds, 7)],
                [Card(.spades, 3), Card(.hearts, 11)],
                [Card(.clubs, 12), Card(.spades, 7)],
                [Card(.hearts, 4)],
                [Card(.diamonds, 4), Card(.clubs, 10)],
                [Card(.hearts, 6)],
                [Card(.clubs, 3), Card(.diamonds, 13)],
                [Card(.spades, 6), Card(.clubs, 9)]
            ],
            cells: [Card(.clubs, 13), nil, nil, nil],
            foundations: [.diamonds: 1]
        ),
        solution: [
            FreeCellMove(from: .tableau(0), count: 4, to: .tableau(1)),
            FreeCellMove(from: .tableau(0), count: 1, to: .foundation(Suit.diamonds.rawValue))
        ],
        goal: { $0.foundations[Suit.diamonds.rawValue].count >= 2 }
    )
}

// MARK: - Spider

struct SpiderLesson: Identifiable {
    let id: String
    let text: LessonText
    let board: Spider
    let solution: [Spider.Suggestion]
    let goal: (Spider) -> Bool

    static let all: [SpiderLesson] = [basics, runs, emptyColumns, dealing]

    /// A column: the first `hidden` cards are face down.
    private struct Col {
        var hidden: Int
        var cards: [(Int, Suit)]
        init(_ hidden: Int = 0, _ cards: [(Int, Suit)]) {
            self.hidden = hidden
            self.cards = cards
        }
    }

    /// Builds a board with unique card ids. Face-down cards get faces too,
    /// but nobody sees them.
    private static func makeBoard(suits: Int, _ columns: [Col], stock: Int = 0) -> Spider {
        var next = 0
        func card(_ rank: Int, _ suit: Suit) -> SpiderCard {
            defer { next += 1 }
            return SpiderCard(id: next, face: Card(suit, rank))
        }
        var board = Spider(suits: suits)
        for (i, column) in columns.enumerated() {
            board.tableau[i].cards = column.cards.map { card($0.0, $0.1) }
            board.tableau[i].hidden = column.hidden
        }
        board.stock = (0..<stock).map { card(($0 * 5) % 13 + 1, .spades) }
        return board
    }

    static let basics = SpiderLesson(
        id: "spider.goal",
        text: LessonText(
            title: "The goal",
            summary: "Spider is played with two decks in ten columns. Build a full run from king down to ace in one suit, and the run leaves the table. Clear all eight runs to win.",
            rules: [
                "Any card can go on a card one rank higher, whatever the suit.",
                "A finished king-to-ace run of one suit moves off the table by itself.",
                "When a face-down card is uncovered, it turns over."
            ],
            tips: "Start with 1 suit while you learn. With 2 or 4 suits, mixing suits is allowed but makes runs you can't move, so it is harder.",
            prompt: "One card is missing from the run of spades. Move the ace of spades onto the 2 to finish it.",
            success: "The run was complete, so it moved off the table. Seven more like that and the game is won."
        ),
        board: makeBoard(suits: 1, [
            Col(0, (2...13).reversed().map { ($0, Suit.spades) }),
            Col(1, [(12, .spades), (1, .spades)]),
            Col(2, [(4, .spades), (6, .spades), (9, .spades)]),
            Col(1, [(10, .spades), (5, .spades)]),
            Col(2, [(3, .spades), (8, .spades), (11, .spades)]),
            Col(0, [(7, .spades)]),
            Col(1, [(13, .spades), (3, .spades)]),
            Col(1, [(2, .spades), (10, .spades)]),
            Col(2, [(9, .spades), (12, .spades), (6, .spades)]),
            Col(0, [(8, .spades)])
        ]),
        solution: [.move(SpiderMove(from: 1, count: 1, to: 0))],
        goal: { !$0.completed.isEmpty }
    )

    static let runs = SpiderLesson(
        id: "spider.runs",
        text: LessonText(
            title: "Moving runs",
            summary: "Several cards can move together only when they are in order and all the same suit. A stack that mixes suits has to be taken apart one card at a time.",
            rules: [
                "A same-suit run, like 6 and 5 of spades, moves as one.",
                "A mixed stack, like a red 7 holding a black 6, can't move as a group.",
                "Prefer to build on the same suit, so your runs stay movable."
            ],
            tips: "When you can choose between two spots for a card, pick the one of the same suit. It costs nothing now and keeps the column free to move later.",
            prompt: "The 6 and 5 of spades are a run, but the 7 of hearts above them is a different suit. Move the spade run onto the 7 of spades.",
            success: "The spades are now a longer same-suit run, and the 7 of hearts is free to move on its own."
        ),
        board: makeBoard(suits: 2, [
            Col(2, [(11, .spades), (3, .hearts), (7, .hearts), (6, .spades), (5, .spades)]),
            Col(1, [(4, .spades), (8, .hearts), (7, .spades)]),
            Col(1, [(9, .hearts), (12, .hearts)]),
            Col(2, [(1, .hearts), (2, .hearts), (4, .hearts)]),
            Col(1, [(5, .hearts), (9, .spades)]),
            Col(0, [(13, .hearts)]),
            Col(1, [(10, .spades), (2, .spades)]),
            Col(2, [(6, .hearts), (1, .spades), (10, .hearts)]),
            Col(1, [(3, .spades), (8, .spades)]),
            Col(1, [(12, .spades), (11, .hearts)])
        ]),
        solution: [.move(SpiderMove(from: 0, count: 2, to: 1))],
        goal: { board in
            let faces = board.tableau[1].cards.suffix(3).map(\.face)
            return faces == [Card(.spades, 7), Card(.spades, 6), Card(.spades, 5)]
        }
    )

    static let emptyColumns = SpiderLesson(
        id: "spider.empty",
        text: LessonText(
            title: "Empty columns",
            summary: "Any card or same-suit run can go into an empty column. An empty column is the most useful space on the table, because it lets you rearrange cards that fit nowhere else.",
            rules: [
                "Empty a column by moving all its cards away, then use it as a parking spot.",
                "Kings can only move into an empty column, since nothing ranks higher.",
                "Turning over face-down cards matters most. Use empty columns to reach them."
            ],
            tips: "Don't fill an empty column just because you can. Wait until it frees a face-down card or joins two runs.",
            prompt: "Two face-down cards are under the 3 of spades and the 9 of hearts. Park the 9 in the empty column, then put the 3 on the 4 of spades.",
            success: "With the 9 parked, the 3 joined the 4 of spades and a face-down card turned over."
        ),
        board: makeBoard(suits: 2, [
            Col(1, [(5, .hearts), (13, .spades)]),
            Col(1, [(8, .hearts), (7, .hearts)]),
            Col(2, [(1, .spades), (4, .hearts), (12, .spades)]),
            Col(0, []),
            Col(1, [(2, .spades), (11, .hearts)]),
            Col(2, [(10, .spades), (6, .hearts), (3, .spades), (9, .hearts)]),
            Col(1, [(1, .hearts), (4, .spades)]),
            Col(1, [(13, .hearts), (6, .spades)]),
            Col(2, [(9, .spades), (12, .hearts), (2, .hearts)]),
            Col(1, [(5, .spades), (8, .spades)])
        ]),
        solution: [
            .move(SpiderMove(from: 5, count: 1, to: 3)),
            .move(SpiderMove(from: 5, count: 1, to: 6))
        ],
        goal: { $0.tableau[5].hidden < 2 }
    )

    static let dealing = SpiderLesson(
        id: "spider.dealing",
        text: LessonText(
            title: "Dealing new cards",
            summary: "When you run out of useful moves, tap the stock in the top right corner. It deals one new card onto every column. There are five deals in a game.",
            rules: [
                "Every column needs at least one card before you can deal.",
                "A deal covers every column, including your runs, so make your moves first.",
                "The Deal button shows how many deals are left."
            ],
            tips: "Before dealing, make every move that helps. Once new cards land on your runs, it gets harder to move them.",
            prompt: "No useful moves are left, but one column is empty. Move the king of hearts into it, then tap the stock to deal.",
            success: "Every column had a card, so the deal went ahead and each column got a new card."
        ),
        board: makeBoard(suits: 2, [
            Col(2, [(4, .spades), (10, .hearts), (13, .hearts)]),
            Col(1, [(8, .hearts), (2, .spades)]),
            Col(1, [(5, .spades), (9, .hearts)]),
            Col(2, [(11, .hearts), (7, .spades), (4, .hearts)]),
            Col(0, []),
            Col(1, [(6, .hearts), (12, .spades)]),
            Col(1, [(3, .hearts), (7, .hearts)]),
            Col(2, [(2, .hearts), (1, .spades), (11, .spades)]),
            Col(1, [(12, .hearts), (6, .spades)]),
            Col(1, [(9, .spades), (1, .hearts)])
        ], stock: 10),
        solution: [.move(SpiderMove(from: 0, count: 1, to: 4)), .deal],
        goal: { $0.stock.isEmpty }
    )
}

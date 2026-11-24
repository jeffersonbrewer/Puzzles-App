import SwiftUI

/// Where everything sits on the board, for a given size and position.
struct BoardLayout {
    let board: Klondike
    let size: CGSize
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    private static let margin: CGFloat = 6
    private static let gap: CGFloat = 5
    private static let rowGap: CGFloat = 18

    init(board: Klondike, size: CGSize) {
        self.board = board
        self.size = size
        // Capped so short screens keep room for the columns.
        let fit = (size.width - 2 * Self.margin - 6 * Self.gap) / 7
        cardWidth = max(20, min(fit, size.height / 7.5))
        cardHeight = CardView.height(forWidth: cardWidth)
    }

    private func columnX(_ column: Int) -> CGFloat {
        let total = 7 * cardWidth + 6 * Self.gap
        return (size.width - total) / 2 + CGFloat(column) * (cardWidth + Self.gap)
    }

    private var tableauY: CGFloat { cardHeight + Self.rowGap }

    /// The frame of an empty pile.
    func slot(_ pile: Pile) -> CGRect {
        let origin: CGPoint
        switch pile {
        case .foundation(let i): origin = CGPoint(x: columnX(i), y: 0)
        case .waste: origin = CGPoint(x: columnX(5), y: 0)
        case .stock: origin = CGPoint(x: columnX(6), y: 0)
        case .tableau(let i): origin = CGPoint(x: columnX(i), y: tableauY)
        }
        return CGRect(origin: origin, size: CGSize(width: cardWidth, height: cardHeight))
    }

    /// The frame of one card.
    func frame(_ pile: Pile, index: Int) -> CGRect {
        var rect = slot(pile)
        switch pile {
        case .stock, .foundation:
            break
        case .waste:
            // The last three cards are fanned to the left of the top one.
            let fromTop = board.waste.count - 1 - index
            rect.origin.x -= CGFloat(min(fromTop, 2)) * cardWidth * 0.48
        case .tableau(let i):
            let column = board.tableau[i]
            let (down, up) = spacing(column)
            rect.origin.y += CGFloat(min(index, column.hidden)) * down + CGFloat(max(0, index - column.hidden)) * up
        }
        return rect
    }

    /// Vertical steps for face-down and face-up cards, squeezed for long columns.
    private func spacing(_ column: TableauColumn) -> (down: CGFloat, up: CGFloat) {
        let down = cardHeight * 0.18, up = cardHeight * 0.40
        let faceUp = column.cards.count - column.hidden
        let needed = CGFloat(column.hidden) * down + CGFloat(max(0, faceUp - 1)) * up
        let available = size.height - tableauY - cardHeight
        guard needed > available, needed > 0 else { return (down, up) }
        let squeeze = max(0.3, available / needed)
        return (down * squeeze, up * squeeze)
    }

    /// The area that accepts a drop.
    func dropFrame(_ pile: Pile) -> CGRect {
        let count = board.cards(in: pile).count
        guard case .tableau = pile, count > 0 else { return slot(pile) }
        return slot(pile).union(frame(pile, index: count - 1))
    }
}

private struct PlacedCard: Identifiable {
    let card: Card
    let pile: Pile
    let index: Int
    let faceUp: Bool
    var id: Int { card.id }
}

/// The whole table. Every card is one view that keeps its identity as it
/// moves between piles, so moves animate by themselves.
struct SolitaireBoardView: View {
    @ObservedObject var game: SolitaireGame

    private struct DragInfo: Equatable {
        var cards: Set<Card>
        var offset: CGSize
    }

    private static let space = "solitaire.board"
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.3, dampingFraction: 0.85)))
    private var drag: DragInfo?
    /// The cards picked up last, kept on top if they slide back.
    @State private var dragged: Set<Card> = []

    var body: some View {
        GeometryReader { geo in
            let layout = BoardLayout(board: game.board, size: geo.size)
            ZStack(alignment: .topLeading) {
                slots(layout)
                ForEach(placedCards) { placed in
                    cardView(placed, layout)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .coordinateSpace(.named(Self.space))
        }
        // After any move `lastMoved` decides what's on top.
        .onChange(of: game.board) { dragged = [] }
        .sensoryFeedback(.impact(weight: .light), trigger: game.moves)
        .sensoryFeedback(.warning, trigger: game.rejections)
    }

    // MARK: Cards

    /// All 52 cards in a fixed order.
    private var placedCards: [PlacedCard] {
        let board = game.board
        var result: [PlacedCard] = []
        result.reserveCapacity(52)
        func add(_ pile: Pile, faceUp: (Int) -> Bool) {
            for (i, card) in board.cards(in: pile).enumerated() {
                result.append(PlacedCard(card: card, pile: pile, index: i, faceUp: faceUp(i)))
            }
        }
        add(.stock) { _ in false }
        add(.waste) { _ in true }
        for i in 0..<4 { add(.foundation(i)) { _ in true } }
        for i in 0..<7 { add(.tableau(i)) { $0 >= board.tableau[i].hidden } }
        return result.sorted { $0.id < $1.id }
    }

    private func cardView(_ placed: PlacedCard, _ layout: BoardLayout) -> some View {
        let rect = layout.frame(placed.pile, index: placed.index)
        let isDragged = drag?.cards.contains(placed.card) ?? false
        let offset = isDragged ? (drag?.offset ?? .zero) : .zero
        return CardView(
            card: placed.card,
            faceUp: placed.faceUp,
            width: layout.cardWidth,
            highlighted: isHighlighted(placed)
        )
        .shadow(color: .black.opacity(isDragged ? 0.3 : 0), radius: isDragged ? 6 : 0, y: isDragged ? 3 : 0)
        .position(x: rect.midX, y: rect.midY)
        .offset(offset)
        .zIndex(zIndex(placed, isDragged: isDragged))
        .onTapGesture { game.tapCard(placed.pile, index: placed.index) }
        .gesture(dragGesture(placed, layout))
        .accessibilityAction { game.tapCard(placed.pile, index: placed.index) }
        .accessibilityHidden(isBuried(placed))
    }

    private func zIndex(_ placed: PlacedCard, isDragged: Bool) -> Double {
        var z = Double(placed.index + 1)
        if game.lastMoved.contains(placed.card) { z += 100 }
        if dragged.contains(placed.card) { z += 200 }
        if isDragged { z += 1000 }
        return z
    }

    private func isHighlighted(_ placed: PlacedCard) -> Bool {
        guard let hint = game.hint else { return false }
        if hint.cards.contains(placed.card) { return true }
        return hint.target == placed.pile && placed.index == game.board.cards(in: placed.pile).count - 1
    }

    /// Cards VoiceOver should skip because something covers them.
    private func isBuried(_ placed: PlacedCard) -> Bool {
        switch placed.pile {
        case .tableau: return !placed.faceUp
        default: return placed.index != game.board.cards(in: placed.pile).count - 1
        }
    }

    // MARK: Dragging

    private func dragGesture(_ placed: PlacedCard, _ layout: BoardLayout) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.space))
            .updating($drag) { value, state, _ in
                guard game.acceptsInput,
                      let count = game.board.pickupCount(placed.pile, index: placed.index) else { return }
                let cards = Set(game.board.cards(in: placed.pile).suffix(count))
                state = DragInfo(cards: cards, offset: value.translation)
            }
            .onChanged { _ in
                guard game.acceptsInput,
                      let count = game.board.pickupCount(placed.pile, index: placed.index) else { return }
                let cards = Set(game.board.cards(in: placed.pile).suffix(count))
                if dragged != cards { dragged = cards }
            }
            .onEnded { value in
                guard let count = game.board.pickupCount(placed.pile, index: placed.index) else { return }
                let held = layout.frame(placed.pile, index: placed.index)
                    .offsetBy(dx: value.translation.width, dy: value.translation.height)
                drop(from: placed.pile, count: count, at: held, layout)
            }
    }

    /// Plays to the legal pile the held card overlaps most. Dropping on an
    /// illegal pile, or back where it came from, returns the card.
    private func drop(from pile: Pile, count: Int, at held: CGRect, _ layout: BoardLayout) {
        let targets: [Pile] = (0..<4).map { Pile.foundation($0) } + (0..<7).map { Pile.tableau($0) }
        let overlaps = targets
            .map { target -> (pile: Pile, area: CGFloat) in
                let hit = layout.dropFrame(target).intersection(held)
                return (target, hit.isNull ? 0 : hit.width * hit.height)
            }
            .filter { $0.area > 0 }
            .sorted { $0.area > $1.area }
        let legal = overlaps.first { game.board.isLegal(KlondikeMove(from: pile, count: count, to: $0.pile)) }
        if let legal {
            game.tryMove(KlondikeMove(from: pile, count: count, to: legal.pile))
        } else if let first = overlaps.first, first.pile != pile {
            game.tryMove(KlondikeMove(from: pile, count: count, to: first.pile))
        }
    }

    // MARK: Empty piles

    private func slots(_ layout: BoardLayout) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Suit.allCases, id: \.rawValue) { suit in
                slot(.foundation(suit.rawValue), symbol: suit.symbol, layout)
            }
            ForEach(0..<7, id: \.self) { i in
                slot(.tableau(i), symbol: nil, layout)
            }
            Button { game.draw() } label: {
                slotBody(.stock, symbol: game.board.canDraw ? "arrow.counterclockwise" : "xmark", layout)
            }
            .buttonStyle(.plain)
            .position(x: layout.slot(.stock).midX, y: layout.slot(.stock).midY)
            .accessibilityLabel("Turn the stock over")
            .accessibilityHidden(!game.board.stock.isEmpty)
        }
    }

    private func slot(_ pile: Pile, symbol: String?, _ layout: BoardLayout) -> some View {
        slotBody(pile, symbol: symbol, layout)
            .position(x: layout.slot(pile).midX, y: layout.slot(pile).midY)
            .accessibilityHidden(true)
    }

    private func slotBody(_ pile: Pile, symbol: String?, _ layout: BoardLayout) -> some View {
        CardSlot(symbol: symbol, width: layout.cardWidth, highlighted: game.hint?.target == pile)
            .contentShape(Rectangle())
    }
}

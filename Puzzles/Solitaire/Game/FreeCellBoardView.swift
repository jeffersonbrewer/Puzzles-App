import SwiftUI

/// Where everything sits on the FreeCell table: free cells and foundations
/// on top, eight columns below.
struct FreeCellLayout {
    let board: FreeCell
    let size: CGSize
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    private static let margin: CGFloat = 4
    private static let gap: CGFloat = 4
    private static let rowGap: CGFloat = 14

    init(board: FreeCell, size: CGSize) {
        self.board = board
        self.size = size
        let fit = (size.width - 2 * Self.margin - 7 * Self.gap) / 8
        cardWidth = max(20, min(fit, size.height / 7.5))
        cardHeight = CardView.height(forWidth: cardWidth)
    }

    private func columnX(_ column: Int) -> CGFloat {
        let total = 8 * cardWidth + 7 * Self.gap
        return (size.width - total) / 2 + CGFloat(column) * (cardWidth + Self.gap)
    }

    private var tableauY: CGFloat { cardHeight + Self.rowGap }

    func slot(_ pile: FreeCellPile) -> CGRect {
        let origin: CGPoint
        switch pile {
        case .cell(let i): origin = CGPoint(x: columnX(i), y: 0)
        case .foundation(let i): origin = CGPoint(x: columnX(4 + i), y: 0)
        case .tableau(let i): origin = CGPoint(x: columnX(i), y: tableauY)
        }
        return CGRect(origin: origin, size: CGSize(width: cardWidth, height: cardHeight))
    }

    func frame(_ pile: FreeCellPile, index: Int) -> CGRect {
        var rect = slot(pile)
        if case .tableau(let i) = pile {
            rect.origin.y += CGFloat(index) * step(board.tableau[i].count)
        }
        return rect
    }

    /// Vertical step between cards, squeezed for long columns.
    private func step(_ count: Int) -> CGFloat {
        let normal = cardHeight * 0.36
        guard count > 1 else { return normal }
        let available = size.height - tableauY - cardHeight
        return min(normal, max(cardHeight * 0.14, available / CGFloat(count - 1)))
    }

    func dropFrame(_ pile: FreeCellPile) -> CGRect {
        let count = board.cards(in: pile).count
        guard case .tableau = pile, count > 0 else { return slot(pile) }
        return slot(pile).union(frame(pile, index: count - 1))
    }
}

/// The FreeCell table. Every card is one view that keeps its identity as it
/// moves, so moves animate by themselves.
struct FreeCellBoardView: View {
    @ObservedObject var game: FreeCellGame

    private struct Placed: Identifiable {
        let card: Card
        let pile: FreeCellPile
        let index: Int
        var id: Int { card.id }
    }

    private struct DragInfo: Equatable {
        var cards: Set<Card>
        var offset: CGSize
    }

    private static let space = "freecell.board"
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.3, dampingFraction: 0.85)))
    private var drag: DragInfo?
    @State private var dragged: Set<Card> = []

    private static let piles: [FreeCellPile] =
        (0..<4).map { FreeCellPile.cell($0) } + (0..<4).map { FreeCellPile.foundation($0) } + (0..<8).map { FreeCellPile.tableau($0) }

    var body: some View {
        GeometryReader { geo in
            let layout = FreeCellLayout(board: game.board, size: geo.size)
            ZStack(alignment: .topLeading) {
                ForEach(Self.piles, id: \.self) { pile in
                    CardSlot(symbol: symbol(pile), width: layout.cardWidth, highlighted: game.hint?.target == pile)
                        .position(x: layout.slot(pile).midX, y: layout.slot(pile).midY)
                        .accessibilityHidden(true)
                }
                ForEach(placedCards) { placed in
                    cardView(placed, layout)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .coordinateSpace(.named(Self.space))
        }
        .onChange(of: game.board) { dragged = [] }
        .sensoryFeedback(.impact(weight: .light), trigger: game.moves)
        .sensoryFeedback(.warning, trigger: game.rejections)
    }

    private func symbol(_ pile: FreeCellPile) -> String? {
        switch pile {
        case .foundation(let i): return Suit(rawValue: i)?.symbol
        case .cell: return "tray"
        case .tableau: return nil
        }
    }

    private var placedCards: [Placed] {
        var result: [Placed] = []
        for pile in Self.piles {
            for (i, card) in game.board.cards(in: pile).enumerated() {
                result.append(Placed(card: card, pile: pile, index: i))
            }
        }
        return result.sorted { $0.id < $1.id }
    }

    private func cardView(_ placed: Placed, _ layout: FreeCellLayout) -> some View {
        let rect = layout.frame(placed.pile, index: placed.index)
        let isDragged = drag?.cards.contains(placed.card) ?? false
        let offset = isDragged ? (drag?.offset ?? .zero) : .zero
        return CardView(card: placed.card, faceUp: true, width: layout.cardWidth, highlighted: isHighlighted(placed))
            .shadow(color: .black.opacity(isDragged ? 0.3 : 0), radius: isDragged ? 6 : 0, y: isDragged ? 3 : 0)
            .position(x: rect.midX, y: rect.midY)
            .offset(offset)
            .zIndex(zIndex(placed, isDragged: isDragged))
            .onTapGesture { game.tapCard(placed.pile, index: placed.index) }
            .gesture(dragGesture(placed, layout))
            .accessibilityAction { game.tapCard(placed.pile, index: placed.index) }
            .accessibilityHidden(placed.index != game.board.cards(in: placed.pile).count - 1
                                 && game.board.pickupCount(placed.pile, index: placed.index) == nil)
    }

    private func zIndex(_ placed: Placed, isDragged: Bool) -> Double {
        var z = Double(placed.index + 1)
        if game.lastMoved.contains(placed.card) { z += 100 }
        if dragged.contains(placed.card) { z += 200 }
        if isDragged { z += 1000 }
        return z
    }

    private func isHighlighted(_ placed: Placed) -> Bool {
        guard let hint = game.hint else { return false }
        if hint.cards.contains(placed.card) { return true }
        return hint.target == placed.pile && placed.index == game.board.cards(in: placed.pile).count - 1
    }

    private func dragGesture(_ placed: Placed, _ layout: FreeCellLayout) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.space))
            .updating($drag) { value, state, _ in
                guard game.acceptsInput,
                      let count = game.board.pickupCount(placed.pile, index: placed.index) else { return }
                state = DragInfo(cards: Set(game.board.cards(in: placed.pile).suffix(count)), offset: value.translation)
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

    /// Plays to the legal pile the held card overlaps most.
    private func drop(from pile: FreeCellPile, count: Int, at held: CGRect, _ layout: FreeCellLayout) {
        let overlaps = Self.piles
            .map { target -> (pile: FreeCellPile, area: CGFloat) in
                let hit = layout.dropFrame(target).intersection(held)
                return (target, hit.isNull ? 0 : hit.width * hit.height)
            }
            .filter { $0.area > 0 }
            .sorted { $0.area > $1.area }
        if let legal = overlaps.first(where: { game.board.isLegal(FreeCellMove(from: pile, count: count, to: $0.pile)) }) {
            game.tryMove(FreeCellMove(from: pile, count: count, to: legal.pile))
        } else if let first = overlaps.first, first.pile != pile {
            game.tryMove(FreeCellMove(from: pile, count: count, to: first.pile))
        }
    }
}

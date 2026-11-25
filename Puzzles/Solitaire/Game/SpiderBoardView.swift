import SwiftUI

/// Where everything sits on the Spider table: finished runs top left, the
/// stock top right, ten columns below.
struct SpiderLayout {
    let board: Spider
    let size: CGSize
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    private static let margin: CGFloat = 3
    private static let gap: CGFloat = 3
    private static let rowGap: CGFloat = 12

    init(board: Spider, size: CGSize) {
        self.board = board
        self.size = size
        let fit = (size.width - 2 * Self.margin - 9 * Self.gap) / 10
        cardWidth = max(18, min(fit, size.height / 8))
        cardHeight = CardView.height(forWidth: cardWidth)
    }

    private func columnX(_ column: Int) -> CGFloat {
        let total = 10 * cardWidth + 9 * Self.gap
        return (size.width - total) / 2 + CGFloat(column) * (cardWidth + Self.gap)
    }

    private var tableauY: CGFloat { cardHeight + Self.rowGap }

    func slot(_ pile: SpiderPile) -> CGRect {
        let origin: CGPoint
        switch pile {
        case .stock: origin = CGPoint(x: columnX(9), y: 0)
        case .foundation(let i): origin = CGPoint(x: columnX(0) + CGFloat(i) * cardWidth * 0.42, y: 0)
        case .tableau(let i): origin = CGPoint(x: columnX(i), y: tableauY)
        }
        return CGRect(origin: origin, size: CGSize(width: cardWidth, height: cardHeight))
    }

    func frame(_ pile: SpiderPile, index: Int) -> CGRect {
        var rect = slot(pile)
        switch pile {
        case .foundation:
            break
        case .stock:
            // One step left for each deal still waiting.
            let deal = index / 10
            let deals = (board.stock.count + 9) / 10
            rect.origin.x -= CGFloat(deals - 1 - deal) * cardWidth * 0.22
        case .tableau(let i):
            let column = board.tableau[i]
            let (down, up) = spacing(column)
            rect.origin.y += CGFloat(min(index, column.hidden)) * down + CGFloat(max(0, index - column.hidden)) * up
        }
        return rect
    }

    private func spacing(_ column: SpiderColumn) -> (down: CGFloat, up: CGFloat) {
        let down = cardHeight * 0.14, up = cardHeight * 0.34
        let faceUp = column.cards.count - column.hidden
        let needed = CGFloat(column.hidden) * down + CGFloat(max(0, faceUp - 1)) * up
        let available = size.height - tableauY - cardHeight
        guard needed > available, needed > 0 else { return (down, up) }
        let squeeze = max(0.25, available / needed)
        return (down * squeeze, up * squeeze)
    }

    func dropFrame(_ column: Int) -> CGRect {
        let count = board.tableau[column].cards.count
        let pile = SpiderPile.tableau(column)
        guard count > 0 else { return slot(pile) }
        return slot(pile).union(frame(pile, index: count - 1))
    }

    /// The whole stock, for tapping.
    var stockFrame: CGRect {
        guard !board.stock.isEmpty else { return slot(.stock) }
        return slot(.stock).union(frame(.stock, index: 0))
    }
}

struct SpiderBoardView: View {
    @ObservedObject var game: SpiderGame

    private struct Placed: Identifiable {
        let card: SpiderCard
        let pile: SpiderPile
        let index: Int
        let faceUp: Bool
        var id: Int { card.id }
    }

    private struct DragInfo: Equatable {
        var cards: Set<SpiderCard>
        var offset: CGSize
    }

    private static let space = "spider.board"
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.3, dampingFraction: 0.85)))
    private var drag: DragInfo?
    @State private var dragged: Set<SpiderCard> = []

    var body: some View {
        GeometryReader { geo in
            let layout = SpiderLayout(board: game.board, size: geo.size)
            ZStack(alignment: .topLeading) {
                slots(layout)
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

    private var placedCards: [Placed] {
        let board = game.board
        var result: [Placed] = []
        result.reserveCapacity(104)
        for (i, card) in board.stock.enumerated() {
            result.append(Placed(card: card, pile: .stock, index: i, faceUp: false))
        }
        for (f, run) in board.completed.enumerated() {
            for (i, card) in run.enumerated() {
                result.append(Placed(card: card, pile: .foundation(f), index: i, faceUp: true))
            }
        }
        for c in 0..<10 {
            for (i, card) in board.tableau[c].cards.enumerated() {
                result.append(Placed(card: card, pile: .tableau(c), index: i, faceUp: i >= board.tableau[c].hidden))
            }
        }
        return result.sorted { $0.id < $1.id }
    }

    private func cardView(_ placed: Placed, _ layout: SpiderLayout) -> some View {
        let rect = layout.frame(placed.pile, index: placed.index)
        let isDragged = drag?.cards.contains(placed.card) ?? false
        let offset = isDragged ? (drag?.offset ?? .zero) : .zero
        return CardView(card: placed.card.face, faceUp: placed.faceUp, width: layout.cardWidth, highlighted: isHighlighted(placed))
            .shadow(color: .black.opacity(isDragged ? 0.3 : 0), radius: isDragged ? 6 : 0, y: isDragged ? 3 : 0)
            .position(x: rect.midX, y: rect.midY)
            .offset(offset)
            .zIndex(zIndex(placed, isDragged: isDragged))
            .onTapGesture { tap(placed) }
            .gesture(dragGesture(placed, layout))
            .accessibilityAction { tap(placed) }
            .accessibilityHidden(isBuried(placed))
    }

    private func tap(_ placed: Placed) {
        switch placed.pile {
        case .stock: game.deal()
        case .foundation: break
        case .tableau(let c): game.tapCard(column: c, index: placed.index)
        }
    }

    private func isBuried(_ placed: Placed) -> Bool {
        switch placed.pile {
        case .tableau: return !placed.faceUp
        default: return placed.index != game.board.cards(in: placed.pile).count - 1
        }
    }

    private func zIndex(_ placed: Placed, isDragged: Bool) -> Double {
        var z = Double(placed.index + 1)
        // Later finished runs overlap earlier ones.
        if case .foundation(let f) = placed.pile { z += Double(f) * 14 }
        if game.lastMoved.contains(placed.card) { z += 200 }
        if dragged.contains(placed.card) { z += 400 }
        if isDragged { z += 1000 }
        return z
    }

    private func isHighlighted(_ placed: Placed) -> Bool {
        guard let hint = game.hint else { return false }
        if hint.cards.contains(placed.card) { return true }
        return hint.target == placed.pile && placed.index == game.board.cards(in: placed.pile).count - 1
    }

    private func dragGesture(_ placed: Placed, _ layout: SpiderLayout) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.space))
            .updating($drag) { value, state, _ in
                guard game.acceptsInput, case .tableau(let c) = placed.pile,
                      let count = game.board.pickupCount(c, index: placed.index) else { return }
                state = DragInfo(cards: Set(game.board.tableau[c].cards.suffix(count)), offset: value.translation)
            }
            .onChanged { _ in
                guard game.acceptsInput, case .tableau(let c) = placed.pile,
                      let count = game.board.pickupCount(c, index: placed.index) else { return }
                let cards = Set(game.board.tableau[c].cards.suffix(count))
                if dragged != cards { dragged = cards }
            }
            .onEnded { value in
                guard case .tableau(let c) = placed.pile,
                      let count = game.board.pickupCount(c, index: placed.index) else { return }
                let held = layout.frame(placed.pile, index: placed.index)
                    .offsetBy(dx: value.translation.width, dy: value.translation.height)
                drop(from: c, count: count, at: held, layout)
            }
    }

    private func drop(from column: Int, count: Int, at held: CGRect, _ layout: SpiderLayout) {
        let overlaps = (0..<10)
            .map { target -> (column: Int, area: CGFloat) in
                let hit = layout.dropFrame(target).intersection(held)
                return (target, hit.isNull ? 0 : hit.width * hit.height)
            }
            .filter { $0.area > 0 }
            .sorted { $0.area > $1.area }
        if let legal = overlaps.first(where: { game.board.isLegal(SpiderMove(from: column, count: count, to: $0.column)) }) {
            game.tryMove(SpiderMove(from: column, count: count, to: legal.column))
        } else if let first = overlaps.first, first.column != column {
            game.tryMove(SpiderMove(from: column, count: count, to: first.column))
        }
    }

    private func slots(_ layout: SpiderLayout) -> some View {
        ZStack(alignment: .topLeading) {
            CardSlot(symbol: "checkmark", width: layout.cardWidth)
                .position(x: layout.slot(.foundation(0)).midX, y: layout.slot(.foundation(0)).midY)
                .accessibilityHidden(true)
            ForEach(0..<10, id: \.self) { i in
                CardSlot(symbol: nil, width: layout.cardWidth, highlighted: game.hint?.target == .tableau(i))
                    .position(x: layout.slot(.tableau(i)).midX, y: layout.slot(.tableau(i)).midY)
                    .accessibilityHidden(true)
            }
            CardSlot(symbol: game.board.stock.isEmpty ? "xmark" : nil, width: layout.cardWidth,
                     highlighted: game.hint?.target == .stock)
                .position(x: layout.slot(.stock).midX, y: layout.slot(.stock).midY)
                .accessibilityHidden(true)
        }
    }
}

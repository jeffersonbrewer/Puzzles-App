import Foundation
import SwiftUI

/// Everything needed to restore an in-progress game.
struct SolitaireSave: Codable {
    var deal: Klondike
    var board: Klondike
    /// 1 or 3
    var drawCount: Int
    var moves = 0
    var elapsed: TimeInterval = 0
    var undoStack: [Klondike] = []

    init(deal: Klondike, drawCount: Int) {
        self.deal = deal
        board = deal
        self.drawCount = drawCount
    }
}

/// A hint: the cards and pile to highlight, plus a line of text.
struct SolitaireHint: Equatable {
    var text: String
    var cards: Set<Card> = []
    var target: Pile?
}

@MainActor
final class SolitaireGame: ObservableObject {
    @Published private(set) var save: SolitaireSave
    @Published private(set) var isPaused = false
    @Published private(set) var isFinishing = false
    @Published private(set) var hint: SolitaireHint?
    /// Cards changed by the latest move, drawn above the others while they travel.
    @Published private(set) var lastMoved: Set<Card> = []
    /// Counts taps and drops that weren't legal, for feedback.
    @Published private(set) var rejections = 0

    private var runningSince: Date?
    private var finishTask: Task<Void, Never>?
    private var isRetired = false
    private static let saveKey = "solitaire.currentGame"
    private static let maxUndo = 300
    private static let moveAnimation = Animation.spring(response: 0.3, dampingFraction: 0.85)

    init(drawCount: Int) {
        save = SolitaireSave(deal: .randomDeal(), drawCount: drawCount)
        persist()
    }

    init(restoring save: SolitaireSave) {
        self.save = save
    }

    // MARK: - Saved game

    static func loadSaved() -> SolitaireSave? {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(SolitaireSave.self, from: data)
    }

    private func persist() {
        guard !isRetired else { return }
        var copy = save
        copy.elapsed = elapsed
        if let data = try? JSONEncoder().encode(copy) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    // MARK: - Read-only helpers

    var board: Klondike { save.board }
    var drawCount: Int { save.drawCount }
    var moves: Int { save.moves }
    var isComplete: Bool { save.board.isWon }
    var acceptsInput: Bool { !isPaused && !isFinishing && !isComplete }
    var canUndo: Bool { !save.undoStack.isEmpty && acceptsInput }
    var canFinish: Bool { acceptsInput && board.canFinish(drawCount: drawCount) }

    var elapsed: TimeInterval {
        save.elapsed + (runningSince.map { Date().timeIntervalSince($0) } ?? 0)
    }

    // MARK: - Clock

    func start() {
        guard !isComplete, runningSince == nil else { return }
        isPaused = false
        runningSince = Date()
    }

    private func stopClock() {
        guard let since = runningSince else { return }
        save.elapsed += Date().timeIntervalSince(since)
        runningSince = nil
    }

    func pause() {
        guard !isComplete else { return }
        finishTask?.cancel()
        stopClock()
        isPaused = true
        persist()
    }

    func resume() { start() }

    /// Called when leaving the game screen.
    func suspend() {
        finishTask?.cancel()
        stopClock()
        persist()
    }

    /// Called when another deal replaces this one, so this one no longer
    /// writes over the saved game.
    func retire() {
        finishTask?.cancel()
        isRetired = true
    }

    // MARK: - Moves

    func tapCard(_ pile: Pile, index: Int) {
        guard acceptsInput else { return }
        if pile == .stock { return draw() }
        // Only the top waste card is live, but a tap on the fan means that card.
        let index = pile == .waste ? board.waste.count - 1 : index
        if let move = board.bestMove(from: pile, index: index) {
            perform(move)
        } else if board.pickupCount(pile, index: index) != nil {
            if case .foundation = pile { return }
            rejections += 1
        }
    }

    /// Returns false if the move isn't legal.
    @discardableResult
    func tryMove(_ move: KlondikeMove) -> Bool {
        guard acceptsInput else { return false }
        guard board.isLegal(move) else {
            rejections += 1
            return false
        }
        perform(move)
        return true
    }

    private func perform(_ move: KlondikeMove) {
        var next = board
        next.apply(move)
        commit(next)
    }

    func draw() {
        guard acceptsInput, board.canDraw else { return }
        var next = board
        next.draw(drawCount)
        commit(next)
    }

    private func commit(_ next: Klondike) {
        pushUndo()
        hint = nil
        show(next)
        save.moves += 1
        if next.isWon { complete() }
        persist()
    }

    /// Animates the board to a new position.
    private func show(_ next: Klondike) {
        let old = Self.locations(board)
        let new = Self.locations(next)
        lastMoved = Set(Card.deck.filter { old[$0] != new[$0] })
        withAnimation(Self.moveAnimation) { save.board = next }
    }

    private static func locations(_ board: Klondike) -> [Card: Pile] {
        var result: [Card: Pile] = [:]
        let piles: [Pile] = [.stock, .waste] + (0..<4).map { Pile.foundation($0) } + (0..<7).map { Pile.tableau($0) }
        for pile in piles {
            for card in board.cards(in: pile) { result[card] = pile }
        }
        return result
    }

    func undo() {
        guard canUndo, let previous = save.undoStack.popLast() else { return }
        hint = nil
        show(previous)
        save.moves += 1
        persist()
    }

    /// Deals the same cards again and resets the clock.
    func restart() {
        finishTask?.cancel()
        stopClock()
        hint = nil
        show(save.deal)
        save.undoStack = []
        save.moves = 0
        save.elapsed = 0
        isPaused = false
        start()
        persist()
    }

    private func pushUndo() {
        save.undoStack.append(board)
        if save.undoStack.count > Self.maxUndo { save.undoStack.removeFirst() }
    }

    private func complete() {
        stopClock()
        save.undoStack = []
        hint = nil
    }

    // MARK: - Finishing

    /// Plays out the remaining cards once every card is face up.
    func finish() {
        guard canFinish else { return }
        hint = nil
        pushUndo()
        isFinishing = true
        finishTask = Task { [weak self] in
            while let self, !Task.isCancelled, !self.board.isWon {
                var next = self.board
                guard next.finishStep() else { break }
                self.show(next)
                self.save.moves += 1
                try? await Task.sleep(for: .milliseconds(90))
            }
            guard let self else { return }
            self.isFinishing = false
            if self.board.isWon { self.complete() }
            self.persist()
        }
    }

    // MARK: - Hints

    func requestHint() {
        guard acceptsInput else { return }
        switch board.suggestion(drawCount: drawCount) {
        case .move(let move):
            let moving = Array(board.cards(in: move.from).suffix(move.count))
            let name = moving.first?.name ?? "card"
            hint = SolitaireHint(text: "\(name) → \(describe(move.to))", cards: Set(moving), target: move.to)
        case .draw:
            hint = SolitaireHint(
                text: board.stock.isEmpty ? "Turn the stock over and keep drawing." : "Draw from the stock.",
                target: .stock
            )
        case nil:
            hint = SolitaireHint(text: "No helpful move found. Try Undo, or start a new deal.")
        }
    }

    private func describe(_ pile: Pile) -> String {
        switch pile {
        case .tableau(let i):
            return board.tableau[i].cards.last.map(\.name) ?? "empty column"
        default:
            return "its foundation"
        }
    }

    func dismissHint() { hint = nil }
}

import Foundation
import SwiftUI

/// Everything needed to restore an in-progress FreeCell game.
struct FreeCellSave: Codable {
    var deal: FreeCell
    var board: FreeCell
    var moves = 0
    var elapsed: TimeInterval = 0
    var undoStack: [FreeCell] = []

    init(deal: FreeCell) {
        self.deal = deal
        board = deal
    }
}

/// A hint: the cards and pile to highlight, plus a line of text.
struct FreeCellHint: Equatable {
    var text: String
    var cards: Set<Card> = []
    var target: FreeCellPile?
}

@MainActor
final class FreeCellGame: ObservableObject {
    @Published private(set) var save: FreeCellSave
    @Published private(set) var isPaused = false
    @Published private(set) var isFinishing = false
    @Published private(set) var hint: FreeCellHint?
    /// Cards changed by the latest move, drawn above the others while they travel.
    @Published private(set) var lastMoved: Set<Card> = []
    /// Counts taps and drops that weren't legal, for feedback.
    @Published private(set) var rejections = 0
    /// Lessons watch this to check the player's move.
    @Published private(set) var lastMove: FreeCellMove?

    /// Lesson boards are never saved.
    let isLesson: Bool
    private var runningSince: Date?
    private var finishTask: Task<Void, Never>?
    private var isRetired = false
    private static let saveKey = "freecell.currentGame"
    private static let maxUndo = 300
    private static let moveAnimation = Animation.spring(response: 0.3, dampingFraction: 0.85)

    init() {
        isLesson = false
        save = FreeCellSave(deal: .randomDeal())
        persist()
    }

    init(restoring save: FreeCellSave) {
        isLesson = false
        self.save = save
    }

    /// A practice board for a lesson.
    init(lesson board: FreeCell) {
        isLesson = true
        save = FreeCellSave(deal: board)
    }

    // MARK: - Saved game

    static func loadSaved() -> FreeCellSave? {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(FreeCellSave.self, from: data)
    }

    private func persist() {
        guard !isRetired, !isLesson else { return }
        var copy = save
        copy.elapsed = elapsed
        if let data = try? JSONEncoder().encode(copy) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    // MARK: - Read-only helpers

    var board: FreeCell { save.board }
    var moves: Int { save.moves }
    var isComplete: Bool { save.board.isWon }
    var acceptsInput: Bool { !isPaused && !isFinishing && !isComplete }
    var canUndo: Bool { !save.undoStack.isEmpty && acceptsInput }
    var canFinish: Bool { acceptsInput && board.canFinish }

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
        isFinishing = false
        stopClock()
        isPaused = true
        persist()
    }

    func resume() { start() }

    /// Called when leaving the game screen.
    func suspend() {
        finishTask?.cancel()
        isFinishing = false
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

    func tapCard(_ pile: FreeCellPile, index: Int) {
        guard acceptsInput else { return }
        if let move = board.bestMove(from: pile, index: index) {
            perform(move)
        } else if case .foundation = pile {
            return
        } else {
            rejections += 1
        }
    }

    /// Returns false if the move isn't legal.
    @discardableResult
    func tryMove(_ move: FreeCellMove) -> Bool {
        guard acceptsInput else { return false }
        guard board.isLegal(move) else {
            rejections += 1
            return false
        }
        perform(move)
        return true
    }

    private func perform(_ move: FreeCellMove) {
        var next = board
        next.apply(move)
        lastMove = move
        commit(next)
    }

    private func commit(_ next: FreeCell) {
        pushUndo()
        hint = nil
        show(next)
        save.moves += 1
        if next.isWon { complete() }
        persist()
    }

    /// Animates the board to a new position.
    private func show(_ next: FreeCell) {
        let old = Self.locations(board)
        let new = Self.locations(next)
        lastMoved = Set(new.keys.filter { old[$0] != new[$0] })
        withAnimation(Self.moveAnimation) { save.board = next }
    }

    private static func locations(_ board: FreeCell) -> [Card: FreeCellPile] {
        var result: [Card: FreeCellPile] = [:]
        let piles: [FreeCellPile] = (0..<4).map { FreeCellPile.cell($0) } + (0..<4).map { FreeCellPile.foundation($0) } + (0..<8).map { FreeCellPile.tableau($0) }
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
        isFinishing = false
        stopClock()
        hint = nil
        lastMove = nil
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

    /// Plays out the remaining cards once every column is in order.
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
        guard let move = board.suggestion() else {
            hint = FreeCellHint(text: "No helpful move found. Try Undo, or start a new deal.")
            return
        }
        show(hint: move)
    }

    /// Highlights a move without making it.
    func show(hint move: FreeCellMove) {
        let moving = Array(board.cards(in: move.from).suffix(move.count))
        let name = moving.first?.name ?? "card"
        let what = move.count > 1 ? "\(name) and the \(move.count - 1) below it" : name
        hint = FreeCellHint(text: "\(what) → \(describe(move.to))", cards: Set(moving), target: move.to)
    }

    private func describe(_ pile: FreeCellPile) -> String {
        switch pile {
        case .tableau(let i): return board.tableau[i].last.map(\.name) ?? "empty column"
        case .cell: return "a free cell"
        case .foundation: return "its foundation"
        }
    }

    func dismissHint() { hint = nil }
}

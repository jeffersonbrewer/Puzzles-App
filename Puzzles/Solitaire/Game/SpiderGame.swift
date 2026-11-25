import Foundation
import SwiftUI

/// Everything needed to restore an in-progress Spider game.
struct SpiderSave: Codable {
    var deal: Spider
    var board: Spider
    var moves = 0
    var elapsed: TimeInterval = 0
    var undoStack: [Spider] = []

    init(deal: Spider) {
        self.deal = deal
        board = deal
    }

    var suits: Int { deal.suits }
}

struct SpiderHint: Equatable {
    var text: String
    var cards: Set<SpiderCard> = []
    var target: SpiderPile?
}

@MainActor
final class SpiderGame: ObservableObject {
    @Published private(set) var save: SpiderSave
    @Published private(set) var isPaused = false
    @Published private(set) var hint: SpiderHint?
    @Published private(set) var lastMoved: Set<SpiderCard> = []
    @Published private(set) var rejections = 0
    /// Lessons watch this to check the player's move.
    @Published private(set) var lastAction: Spider.Suggestion?

    let isLesson: Bool
    private var runningSince: Date?
    private var isRetired = false
    private static let saveKey = "spider.currentGame"
    private static let maxUndo = 300
    private static let moveAnimation = Animation.spring(response: 0.3, dampingFraction: 0.85)

    init(suits: Int) {
        isLesson = false
        save = SpiderSave(deal: .randomDeal(suits: suits))
        persist()
    }

    init(restoring save: SpiderSave) {
        isLesson = false
        self.save = save
    }

    init(lesson board: Spider) {
        isLesson = true
        save = SpiderSave(deal: board)
    }

    static func title(suits: Int) -> String { suits == 1 ? "1 Suit" : "\(suits) Suits" }

    // MARK: - Saved game

    static func loadSaved() -> SpiderSave? {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(SpiderSave.self, from: data)
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

    var board: Spider { save.board }
    var suits: Int { save.suits }
    var moves: Int { save.moves }
    var isComplete: Bool { save.board.isWon }
    var acceptsInput: Bool { !isPaused && !isComplete }
    var canUndo: Bool { !save.undoStack.isEmpty && acceptsInput }

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
        stopClock()
        isPaused = true
        persist()
    }

    func resume() { start() }

    func suspend() {
        stopClock()
        persist()
    }

    func retire() { isRetired = true }

    // MARK: - Moves

    func tapCard(column: Int, index: Int) {
        guard acceptsInput else { return }
        if let move = board.bestMove(from: column, index: index) {
            perform(move)
        } else {
            rejections += 1
        }
    }

    @discardableResult
    func tryMove(_ move: SpiderMove) -> Bool {
        guard acceptsInput else { return false }
        guard board.isLegal(move) else {
            rejections += 1
            return false
        }
        perform(move)
        return true
    }

    private func perform(_ move: SpiderMove) {
        var next = board
        next.apply(move)
        lastAction = .move(move)
        commit(next)
    }

    /// Deals a card onto every column. Every column needs at least one card first.
    func deal() {
        guard acceptsInput, !board.stock.isEmpty else { return }
        guard board.canDeal else {
            rejections += 1
            hint = SpiderHint(text: "Fill every empty column before dealing.")
            return
        }
        var next = board
        next.deal()
        lastAction = .deal
        commit(next)
    }

    private func commit(_ next: Spider) {
        pushUndo()
        hint = nil
        show(next)
        save.moves += 1
        if next.isWon { complete() }
        persist()
    }

    private func show(_ next: Spider) {
        let old = Self.locations(board)
        let new = Self.locations(next)
        lastMoved = Set(new.keys.filter { old[$0] != new[$0] })
        withAnimation(Self.moveAnimation) { save.board = next }
    }

    private static func locations(_ board: Spider) -> [SpiderCard: SpiderPile] {
        var result: [SpiderCard: SpiderPile] = [:]
        let piles: [SpiderPile] = [SpiderPile.stock] + (0..<8).map { SpiderPile.foundation($0) } + (0..<10).map { SpiderPile.tableau($0) }
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

    func restart() {
        stopClock()
        hint = nil
        lastAction = nil
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

    // MARK: - Hints

    func requestHint() {
        guard acceptsInput else { return }
        guard let suggestion = board.suggestion() else {
            hint = SpiderHint(text: "No helpful move found. Try Undo, or start a new deal.")
            return
        }
        show(hint: suggestion)
    }

    func show(hint suggestion: Spider.Suggestion) {
        switch suggestion {
        case .deal:
            hint = SpiderHint(text: "Deal a new row from the stock.", target: .stock)
        case .move(let move):
            let moving = Array(board.tableau[move.from].cards.suffix(move.count))
            let name = moving.first?.name ?? "card"
            let what = move.count > 1 ? "\(name) and the \(move.count - 1) below it" : name
            let onto = board.tableau[move.to].cards.last.map(\.name) ?? "empty column"
            hint = SpiderHint(text: "\(what) → \(onto)", cards: Set(moving), target: .tableau(move.to))
        }
    }

    func dismissHint() { hint = nil }
}

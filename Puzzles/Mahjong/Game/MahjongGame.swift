import Foundation
import SwiftUI

/// Everything needed to restore an in-progress game.
struct MahjongSave: Codable {
    var deal: MahjongBoard
    var board: MahjongBoard
    var moves = 0
    var shuffles = 0
    var elapsed: TimeInterval = 0
    var undoStack: [MahjongBoard] = []

    init(deal: MahjongBoard) {
        self.deal = deal
        board = deal
    }
}

/// A hint: the two tiles to highlight, plus a line of text.
struct MahjongHint: Equatable {
    var text: String
    var slots: Set<Int> = []
}

@MainActor
final class MahjongGame: ObservableObject {
    @Published private(set) var save: MahjongSave
    @Published private(set) var isPaused = false
    @Published private(set) var selected: Int?
    @Published private(set) var hint: MahjongHint?
    /// A blocked tile that was just tapped, outlined for a moment.
    @Published private(set) var rejected: Int?
    /// Counts taps on blocked tiles, for feedback.
    @Published private(set) var rejections = 0

    private var runningSince: Date?
    private var hintCursor = 0
    private var rejectTask: Task<Void, Never>?
    private var isRetired = false
    private static let saveKey = "mahjong.currentGame"
    private static let maxUndo = 200
    static let removeAnimation = Animation.easeOut(duration: 0.22)

    init(layout: MahjongLayout) {
        save = MahjongSave(deal: .deal(layout))
        persist()
    }

    init(restoring save: MahjongSave) {
        self.save = save
    }

    // MARK: - Saved game

    static func loadSaved() -> MahjongSave? {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(MahjongSave.self, from: data)
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

    var board: MahjongBoard { save.board }
    var layout: MahjongLayout { save.board.layout }
    var moves: Int { save.moves }
    var isComplete: Bool { save.board.isCleared }
    var acceptsInput: Bool { !isPaused && !isComplete }
    var canUndo: Bool { !save.undoStack.isEmpty && acceptsInput }
    /// Matching pairs that can be removed right now.
    var openPairCount: Int { board.openPairs().count }
    var isStuck: Bool { !isComplete && board.openPairs().isEmpty }

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

    /// Called when leaving the game screen.
    func suspend() {
        stopClock()
        persist()
    }

    /// Called when another deal replaces this one, so this one no longer
    /// writes over the saved game.
    func retire() { isRetired = true }

    // MARK: - Moves

    func tap(_ slot: Int) {
        guard acceptsInput, let tile = board.tiles[slot] else { return }
        guard board.isFree(slot) else {
            selected = nil
            flagBlocked(slot)
            return
        }
        if selected == slot {
            selected = nil
        } else if let first = selected, let other = board.tiles[first], other.matches(tile) {
            removePair(first, slot)
        } else {
            selected = slot
        }
    }

    private func removePair(_ a: Int, _ b: Int) {
        guard board.canRemove(a, b) else { return }
        pushUndo()
        var next = board
        next.remove(a, b)
        selected = nil
        hint = nil
        hintCursor = 0
        withAnimation(Self.removeAnimation) { save.board = next }
        save.moves += 1
        if next.isCleared { complete() }
        persist()
    }

    private func flagBlocked(_ slot: Int) {
        rejections += 1
        rejected = slot
        rejectTask?.cancel()
        rejectTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            self?.rejected = nil
        }
    }

    /// Moves the remaining tiles to new spots. It counts as a move and can be undone.
    func shuffle() {
        guard acceptsInput, board.remaining > 0 else { return }
        pushUndo()
        selected = nil
        hint = nil
        hintCursor = 0
        withAnimation(.easeInOut(duration: 0.3)) { save.board = board.reshuffled() }
        save.moves += 1
        save.shuffles += 1
        persist()
    }

    func undo() {
        guard canUndo, let previous = save.undoStack.popLast() else { return }
        selected = nil
        hint = nil
        hintCursor = 0
        withAnimation(Self.removeAnimation) { save.board = previous }
        save.moves += 1
        persist()
    }

    /// Deals the same tiles again and resets the clock.
    func restart() {
        stopClock()
        selected = nil
        hint = nil
        hintCursor = 0
        withAnimation(Self.removeAnimation) { save.board = save.deal }
        save.undoStack = []
        save.moves = 0
        save.shuffles = 0
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

    /// Shows a pair that can be removed. Asking again shows the next one.
    func requestHint() {
        guard acceptsInput else { return }
        let pairs = board.openPairs()
        guard !pairs.isEmpty else {
            hint = MahjongHint(text: "No matches left. Shuffle the tiles, or undo.")
            return
        }
        let (a, b) = pairs[hintCursor % pairs.count]
        hintCursor += 1
        let name = board.tiles[a]?.groupName ?? "these tiles"
        let more = pairs.count > 1 ? " (\(pairs.count) pairs open)" : ""
        hint = MahjongHint(text: "Match \(name)\(more).", slots: [a, b])
    }

    func dismissHint() { hint = nil }
}

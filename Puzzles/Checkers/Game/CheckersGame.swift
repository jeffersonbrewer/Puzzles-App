import Foundation
import SwiftUI

/// Picks a move one tap at a time: a piece, then each square it lands on.
struct CheckersMovePicker {
    /// The chosen piece's square followed by any landings tapped so far.
    private(set) var path: [Int] = []

    enum Result {
        /// Nothing to do; the tap was ignored or cleared the selection.
        case none
        case selected
        case extended
        case completed(CheckersMove)
        /// The tapped piece can't move because a jump elsewhere is required.
        case mustJump
        /// The tapped piece has no legal move.
        case blocked
    }

    var selected: Int? { path.first }

    mutating func clear() { path = [] }

    /// Squares the selected piece can go to next.
    func targets(_ legal: [CheckersMove]) -> Set<Int> {
        guard !path.isEmpty else { return [] }
        return Set(matching(legal).compactMap { $0.path.count > path.count ? $0.path[path.count] : nil })
    }

    private func matching(_ legal: [CheckersMove]) -> [CheckersMove] {
        legal.filter { $0.path.starts(with: path) }
    }

    mutating func tap(_ square: Int, board: Checkers, legal: [CheckersMove]) -> Result {
        if !path.isEmpty {
            let extended = path + [square]
            let candidates = legal.filter { $0.path.starts(with: extended) }
            if !candidates.isEmpty {
                path = extended
                if let done = candidates.first(where: { $0.path.count == extended.count }) {
                    path = []
                    return .completed(done)
                }
                return .extended
            }
            // Partway through a jump, only the next landing counts.
            if path.count > 1 { return .none }
        }
        guard let piece = board.squares[square], piece.side == board.turn else {
            path = []
            return .none
        }
        if legal.contains(where: { $0.from == square }) {
            path = [square]
            return .selected
        }
        path = []
        return legal.first?.isCapture == true ? .mustJump : .blocked
    }
}

/// Everything needed to restore an in-progress game.
struct CheckersSave: Codable {
    var board: Checkers
    var difficulty: CheckersDifficulty
    var playerFirst: Bool
    /// Positions before each of the player's moves, for undo.
    var undoStack: [Checkers] = []
    var lastMove: CheckersMove?
    var moves = 0
    var elapsed: TimeInterval = 0

    init(difficulty: CheckersDifficulty, playerFirst: Bool) {
        board = .start(firstMove: playerFirst ? .player : .computer)
        self.difficulty = difficulty
        self.playerFirst = playerFirst
    }

    var outcome: CheckersOutcome? { board.outcome }
}

@MainActor
final class CheckersGame: ObservableObject {
    @Published private(set) var save: CheckersSave
    @Published private(set) var picker = CheckersMovePicker()
    @Published private(set) var isThinking = false
    @Published private(set) var isAnimating = false
    @Published private(set) var isPaused = false
    @Published private(set) var hint: CheckersMove?
    /// A short message such as "You must jump", cleared by the next move.
    @Published private(set) var notice: String?
    /// Pieces to flash when the player taps one that can't move.
    @Published private(set) var flash: Set<Int> = []

    private var runningSince: Date?
    private var computerTask: Task<Void, Never>?
    /// Bumped whenever the computer's pending move is called off, so a stale search can't play.
    private var computerToken = 0
    private var isRetired = false
    private static let saveKey = "checkers.currentGame"
    private static let hopAnimation = Animation.easeInOut(duration: 0.22)

    init(difficulty: CheckersDifficulty, playerFirst: Bool) {
        save = CheckersSave(difficulty: difficulty, playerFirst: playerFirst)
        persist()
    }

    init(restoring save: CheckersSave) {
        self.save = save
    }

    // MARK: - Saved game

    static func loadSaved() -> CheckersSave? {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(CheckersSave.self, from: data)
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

    var board: Checkers { save.board }
    var difficulty: CheckersDifficulty { save.difficulty }
    var outcome: CheckersOutcome? { save.outcome }
    var isOver: Bool { outcome != nil }
    var isPlayersTurn: Bool { board.turn == .player }
    var acceptsInput: Bool { isPlayersTurn && !isThinking && !isAnimating && !isPaused && !isOver }
    var canUndo: Bool { !save.undoStack.isEmpty && !isAnimating && !isPaused }
    var legalMoves: [CheckersMove] { isPlayersTurn ? board.legalMoves() : [] }
    var targets: Set<Int> { picker.targets(legalMoves) }
    var movablePieces: Set<Int> { acceptsInput ? Set(legalMoves.map(\.from)) : [] }

    var elapsed: TimeInterval {
        save.elapsed + (runningSince.map { Date().timeIntervalSince($0) } ?? 0)
    }

    // MARK: - Clock and lifecycle

    func start() {
        guard !isOver else { return }
        isPaused = false
        if runningSince == nil { runningSince = Date() }
        if !isPlayersTurn { playComputer() }
    }

    private func stopClock() {
        guard let since = runningSince else { return }
        save.elapsed += Date().timeIntervalSince(since)
        runningSince = nil
    }

    func pause() {
        guard !isOver else { return }
        cancelComputer()
        stopClock()
        isPaused = true
        persist()
    }

    func resume() { start() }

    /// Called when leaving the game screen.
    func suspend() {
        cancelComputer()
        stopClock()
        persist()
    }

    /// Called when a new game replaces this one, so it stops saving over it.
    func retire() {
        cancelComputer()
        isRetired = true
    }

    // MARK: - Player input

    func tap(_ square: Int) {
        guard acceptsInput else { return }
        let legal = board.legalMoves()
        let result = picker.tap(square, board: board, legal: legal)
        switch result {
        case .completed(let move):
            play(move)
        case .mustJump:
            notice = "You have a jump, and jumps are required."
            flashPieces(Set(legal.map(\.from)))
        case .blocked:
            notice = "That piece has nowhere to go."
        case .selected, .extended:
            notice = nil
        case .none:
            break
        }
    }

    private func flashPieces(_ squares: Set<Int>) {
        flash = squares
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            self?.flash = []
        }
    }

    private func play(_ move: CheckersMove) {
        save.undoStack.append(board)
        hint = nil
        notice = nil
        Task {
            await animate(move)
            save.moves += 1
            persist()
            if !isOver { playComputer() } else { stopClock() }
        }
    }

    /// Plays a move hop by hop.
    private func animate(_ move: CheckersMove) async {
        isAnimating = true
        let steps = board.animationSteps(move)
        for (i, step) in steps.enumerated() {
            withAnimation(Self.hopAnimation) { save.board = step }
            if i < steps.count - 1 { try? await Task.sleep(for: .milliseconds(260)) }
        }
        save.lastMove = move
        try? await Task.sleep(for: .milliseconds(200))
        isAnimating = false
    }

    // MARK: - Computer

    private func cancelComputer() {
        computerTask?.cancel()
        computerTask = nil
        computerToken += 1
        isThinking = false
    }

    private func playComputer() {
        guard !isPlayersTurn, !isOver, !isPaused, !isThinking else { return }
        isThinking = true
        computerToken += 1
        let token = computerToken
        let board = self.board, difficulty = self.difficulty
        computerTask = Task { [weak self] in
            let started = Date()
            let move = await Task.detached(priority: .userInitiated) {
                CheckersAI.chooseMove(board, difficulty: difficulty)
            }.value
            // A short pause so the reply doesn't feel instant.
            let wait = 0.5 - Date().timeIntervalSince(started)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard let self, self.computerToken == token, !Task.isCancelled else { return }
            guard let move, self.board == board else {
                self.isThinking = false
                return
            }
            await self.animate(move)
            self.isThinking = false
            self.persist()
            if self.isOver { self.stopClock() }
        }
    }

    // MARK: - Controls

    /// Takes back the player's last move and the computer's reply.
    func undo() {
        guard canUndo, let previous = save.undoStack.popLast() else { return }
        cancelComputer()
        picker.clear()
        hint = nil
        notice = nil
        withAnimation(Self.hopAnimation) { save.board = previous }
        save.lastMove = nil
        save.moves = max(0, save.moves - 1)
        if runningSince == nil && !isPaused { runningSince = Date() }
        persist()
    }

    func requestHint() {
        guard acceptsInput else { return }
        picker.clear()
        let board = self.board
        isThinking = true
        Task {
            let move = await Task.detached(priority: .userInitiated) { CheckersAI.hint(board) }.value
            isThinking = false
            guard self.board == board else { return }
            hint = move
            if move != nil { notice = "Try moving the outlined piece to the outlined square." }
        }
    }

    /// Starts a fresh game at the same difficulty.
    func restart() {
        cancelComputer()
        picker.clear()
        hint = nil
        notice = nil
        stopClock()
        withAnimation(Self.hopAnimation) {
            save = CheckersSave(difficulty: save.difficulty, playerFirst: save.playerFirst)
        }
        isPaused = false
        start()
        persist()
    }
}

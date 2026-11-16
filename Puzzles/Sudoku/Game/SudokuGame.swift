import Foundation
import Combine

/// Everything needed to restore an in-progress game.
struct SudokuSave: Codable {
    var puzzle: SudokuPuzzle
    var values: [Int]
    var notes: [UInt16]
    var autoCandidates: Bool = false
    var mistakes: Int = 0
    var elapsed: TimeInterval = 0
    var isComplete: Bool = false
    /// Eliminations the player accepted from hints. Kept so later hints and
    /// auto-candidates don't repeat them.
    var knownEliminations: Set<CellDigit> = []
    var undoStack: [SudokuSnapshot] = []

    init(puzzle: SudokuPuzzle) {
        self.puzzle = puzzle
        values = puzzle.givens
        notes = [UInt16](repeating: 0, count: 81)
    }
}

struct SudokuSnapshot: Codable {
    var values: [Int]
    var notes: [UInt16]
    var autoCandidates: Bool
}

/// A hint shown under the board.
struct SudokuHint {
    var title: String
    var text: String
    var step: LogicStep?
    var focusCell: Int?
}

enum SudokuSettingsKey {
    static let showMistakes = "sudoku.showMistakes"
    static let highlightPeers = "sudoku.highlightPeers"
    static let autoRemoveNotes = "sudoku.autoRemoveNotes"
}

@MainActor
final class SudokuGame: ObservableObject {
    @Published private(set) var save: SudokuSave
    @Published var selected: Int?
    @Published var notesMode = false
    @Published private(set) var isPaused = false
    @Published private(set) var hint: SudokuHint?
    /// Changes once a second while the clock runs, to refresh the timer.
    @Published private(set) var clockTick = 0

    private var runningSince: Date?
    private var timer: Timer?
    private static let saveKey = "sudoku.currentGame"
    private static let maxUndo = 200

    init(puzzle: SudokuPuzzle) {
        save = SudokuSave(puzzle: puzzle)
        persist()
    }

    init(restoring save: SudokuSave) {
        self.save = save
    }

    // MARK: - Saved game

    static func loadSaved() -> SudokuSave? {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(SudokuSave.self, from: data)
    }

    private func persist() {
        var copy = save
        copy.elapsed = elapsed
        if let data = try? JSONEncoder().encode(copy) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    // MARK: - Read-only helpers

    var difficulty: Difficulty { save.puzzle.difficulty }
    var values: [Int] { save.values }
    var givens: [Int] { save.puzzle.givens }
    var notes: [UInt16] { save.notes }
    var autoCandidates: Bool { save.autoCandidates }
    var mistakes: Int { save.mistakes }
    var isComplete: Bool { save.isComplete }
    var canUndo: Bool { !save.undoStack.isEmpty && !isComplete }

    var elapsed: TimeInterval {
        save.elapsed + (runningSince.map { Date().timeIntervalSince($0) } ?? 0)
    }

    func isGiven(_ cell: Int) -> Bool { givens[cell] != 0 }

    func isWrong(_ cell: Int) -> Bool {
        save.values[cell] != 0 && save.values[cell] != save.puzzle.solution[cell]
    }

    var wrongCells: Set<Int> { Set((0..<81).filter(isWrong)) }

    /// How many of each digit are still to be placed (index 1...9).
    func remaining(_ digit: Int) -> Int {
        9 - save.values.filter { $0 == digit }.count
    }

    private var autoRemoveNotes: Bool {
        UserDefaults.standard.object(forKey: SudokuSettingsKey.autoRemoveNotes) as? Bool ?? true
    }

    // MARK: - Clock

    func start() {
        guard !isComplete, runningSince == nil else { return }
        isPaused = false
        runningSince = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.clockTick &+= 1 }
        }
    }

    private func stopClock() {
        if let since = runningSince {
            save.elapsed += Date().timeIntervalSince(since)
            runningSince = nil
        }
        timer?.invalidate()
        timer = nil
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

    // MARK: - Input

    func select(_ cell: Int) {
        guard !isPaused, !isComplete else { return }
        selected = cell
    }

    func input(_ digit: Int) {
        guard let cell = selected, !isGiven(cell), !isComplete, !isPaused else { return }
        hint = nil
        if notesMode {
            toggleNote(cell, digit)
        } else {
            place(cell, digit)
        }
    }

    private func toggleNote(_ cell: Int, _ digit: Int) {
        guard save.values[cell] == 0 else { return }
        pushUndo()
        save.notes[cell] ^= Sudoku.bit(digit)
        persist()
    }

    private func place(_ cell: Int, _ digit: Int) {
        pushUndo()
        let old = save.values[cell]
        if old == digit {
            // Tapping the same number again clears it.
            save.values[cell] = 0
            restoreCandidate(old, around: cell)
            persist()
            return
        }
        if old != 0 {
            save.values[cell] = 0
            restoreCandidate(old, around: cell)
        }
        save.values[cell] = digit
        save.notes[cell] = 0
        if digit != save.puzzle.solution[cell] { save.mistakes += 1 }
        if save.autoCandidates || autoRemoveNotes {
            let b = Sudoku.bit(digit)
            for p in Sudoku.peers[cell] { save.notes[p] &= ~b }
        }
        checkCompletion()
        persist()
    }

    func erase() {
        guard let cell = selected, !isGiven(cell), !isComplete, !isPaused else { return }
        hint = nil
        if save.values[cell] != 0 {
            pushUndo()
            let old = save.values[cell]
            save.values[cell] = 0
            restoreCandidate(old, around: cell)
        } else if save.notes[cell] != 0 {
            pushUndo()
            save.notes[cell] = 0
        }
        persist()
    }

    /// With auto-candidates on, removing a digit makes it possible again for
    /// the cell and its neighbours.
    private func restoreCandidate(_ digit: Int, around cell: Int) {
        guard save.autoCandidates else { return }
        save.notes[cell] = candidates(for: cell)
        for p in Sudoku.peers[cell] where save.values[p] == 0 {
            if candidates(for: p).has(digit) { save.notes[p] |= Sudoku.bit(digit) }
        }
    }

    private func candidates(for cell: Int) -> UInt16 {
        guard save.values[cell] == 0 else { return 0 }
        var mask = Sudoku.allCandidates
        for p in Sudoku.peers[cell] where save.values[p] != 0 { mask &= ~Sudoku.bit(save.values[p]) }
        for d in mask.digits where save.knownEliminations.contains(CellDigit(cell: cell, digit: d)) {
            mask &= ~Sudoku.bit(d)
        }
        return mask
    }

    func toggleAutoCandidates() {
        guard !isComplete, !isPaused else { return }
        hint = nil
        pushUndo()
        if save.autoCandidates {
            save.autoCandidates = false
            save.notes = [UInt16](repeating: 0, count: 81)
        } else {
            save.autoCandidates = true
            save.notes = (0..<81).map { candidates(for: $0) }
        }
        persist()
    }

    func undo() {
        guard let snap = save.undoStack.popLast(), !isComplete else { return }
        hint = nil
        save.values = snap.values
        save.notes = snap.notes
        save.autoCandidates = snap.autoCandidates
        persist()
    }

    func restart() {
        pushUndo()
        hint = nil
        save.values = givens
        save.notes = [UInt16](repeating: 0, count: 81)
        save.autoCandidates = false
        save.knownEliminations = []
        persist()
    }

    private func pushUndo() {
        save.undoStack.append(SudokuSnapshot(values: save.values, notes: save.notes, autoCandidates: save.autoCandidates))
        if save.undoStack.count > Self.maxUndo { save.undoStack.removeFirst() }
    }

    private func checkCompletion() {
        guard save.values == save.puzzle.solution else { return }
        stopClock()
        save.isComplete = true
        save.undoStack = []
        selected = nil
        notesMode = false
    }

    // MARK: - Hints

    func requestHint() {
        guard !isComplete, !isPaused else { return }
        if let wrong = (0..<81).first(where: isWrong) {
            selected = wrong
            hint = SudokuHint(
                title: "Check this cell",
                text: "\(Sudoku.cellName(wrong)) doesn't match the solution. Erase it before going on.",
                step: nil,
                focusCell: wrong
            )
            return
        }
        var grid = CandidateGrid(values: save.values)
        for e in save.knownEliminations { grid.eliminate(e.cell, e.digit) }
        if let step = LogicSolver.nextStep(grid) {
            hint = SudokuHint(title: step.technique.title, text: step.explanation, step: step, focusCell: step.patternCells.first)
        } else {
            hint = SudokuHint(
                title: "No simple step",
                text: "None of the techniques in Training apply here. This position needs a more advanced chain of logic.",
                step: nil,
                focusCell: nil
            )
        }
    }

    func applyHint() {
        guard let step = hint?.step else { hint = nil; return }
        hint = nil
        if let p = step.placements.first {
            selected = p.cell
            place(p.cell, p.digit)
        } else {
            pushUndo()
            for e in step.eliminations {
                save.knownEliminations.insert(e)
                save.notes[e.cell] &= ~Sudoku.bit(e.digit)
            }
            persist()
        }
    }

    func dismissHint() { hint = nil }
}

import Foundation
import SwiftUI

enum NonogramSettingsKey {
    static let showMistakes = "nonograms.showMistakes"
}

/// Which mark a tap or drag makes.
enum NonogramTool: String, Codable {
    case fill, cross
}

/// Everything needed to restore an in-progress puzzle.
struct NonogramSave: Codable {
    var puzzle: NonogramPuzzle
    var cells: [NonoCell]
    var elapsed: TimeInterval = 0
    var mistakes = 0
    var undoStack: [[NonoCell]] = []

    init(puzzle: NonogramPuzzle) {
        self.puzzle = puzzle
        cells = [NonoCell](repeating: .unknown, count: puzzle.cellCount)
    }

    /// Solved when every filled square of the picture is filled and nothing else is.
    var isComplete: Bool {
        cells.indices.allSatisfy { (cells[$0] == .filled) == puzzle.solution[$0] }
    }
}

/// A hint: a line to look at and what it gives, or a mistake to fix.
struct NonogramHint: Equatable {
    var text: String
    var line: NonoLine?
    var fill: Set<Int> = []
    var cross: Set<Int> = []
    var mistakes: Set<Int> = []

    var canApply: Bool { !fill.isEmpty || !cross.isEmpty || !mistakes.isEmpty }
}

/// Solved pictures and best times, kept between games.
enum NonogramRecords {
    private static let solvedKey = "nonograms.solved"
    private static let bestKey = "nonograms.bestTimes"

    static var solved: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: solvedKey) ?? [])
    }

    static func bestTime(_ id: String) -> TimeInterval? {
        (UserDefaults.standard.dictionary(forKey: bestKey) as? [String: Double])?[id]
    }

    static func record(_ id: String, time: TimeInterval) {
        var s = solved
        s.insert(id)
        UserDefaults.standard.set(Array(s).sorted(), forKey: solvedKey)
        var best = (UserDefaults.standard.dictionary(forKey: bestKey) as? [String: Double]) ?? [:]
        if best[id].map({ time < $0 }) ?? true {
            best[id] = time
            UserDefaults.standard.set(best, forKey: bestKey)
        }
    }
}

@MainActor
final class NonogramGame: ObservableObject {
    @Published private(set) var save: NonogramSave
    @Published private(set) var isPaused = false
    @Published private(set) var hint: NonogramHint?
    @Published var tool: NonogramTool = .fill
    /// The square under the finger, so its row and column can be highlighted.
    @Published private(set) var activeCell: Int?

    /// False for practice puzzles from the lessons, which aren't saved.
    let persists: Bool
    private var runningSince: Date?
    private var isRetired = false
    private var stroke: Stroke?
    private static let saveKey = "nonograms.currentGame"
    private static let maxUndo = 300

    /// A drag in progress. Marks are recalculated from `before` on every
    /// move, so dragging back un-marks squares.
    private struct Stroke {
        var start: Int
        var target: NonoCell
        /// Only squares in this state change (so a fill drag doesn't wipe out crosses).
        var replaces: NonoCell
        var horizontal: Bool?
        var before: [NonoCell]
    }

    init(puzzle: NonogramPuzzle, persists: Bool = true) {
        save = NonogramSave(puzzle: puzzle)
        self.persists = persists
        persist()
    }

    init(restoring save: NonogramSave) {
        self.save = save
        persists = true
    }

    // MARK: - Saved game

    static func loadSaved() -> NonogramSave? {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return nil }
        return try? JSONDecoder().decode(NonogramSave.self, from: data)
    }

    private func persist() {
        guard persists, !isRetired else { return }
        var copy = save
        copy.elapsed = elapsed
        if let data = try? JSONEncoder().encode(copy) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }

    // MARK: - Read-only helpers

    var puzzle: NonogramPuzzle { save.puzzle }
    var cells: [NonoCell] { save.cells }
    var isComplete: Bool { save.isComplete }
    var acceptsInput: Bool { !isPaused && !isComplete }
    var canUndo: Bool { !save.undoStack.isEmpty && acceptsInput }
    var mistakes: Int { save.mistakes }

    var elapsed: TimeInterval {
        save.elapsed + (runningSince.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private var showMistakes: Bool {
        UserDefaults.standard.bool(forKey: NonogramSettingsKey.showMistakes)
    }

    func isWrong(_ i: Int) -> Bool {
        switch save.cells[i] {
        case .filled: return !puzzle.solution[i]
        case .crossed: return puzzle.solution[i]
        case .unknown: return false
        }
    }

    /// A line is done when its filled squares match its clue.
    func isLineSatisfied(_ line: NonoLine) -> Bool {
        let filled = puzzle.indices(of: line).map { save.cells[$0] == .filled }
        return NonogramPuzzle.clues(filled) == puzzle.clues(for: line)
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
        endStroke()
        stopClock()
        isPaused = true
        persist()
    }

    func resume() { start() }

    /// Called when leaving the game screen.
    func suspend() {
        endStroke()
        stopClock()
        persist()
    }

    /// Called when another puzzle replaces this one, so this one no longer
    /// writes over the saved game.
    func retire() { isRetired = true }

    // MARK: - Marking squares

    /// A touch on square `i`: starts a stroke, or extends the current one.
    func touch(_ i: Int) {
        if stroke == nil { beginStroke(at: i) } else { continueStroke(to: i) }
    }

    func beginStroke(at i: Int) {
        guard acceptsInput, save.cells.indices.contains(i) else { return }
        let current = save.cells[i]
        let mark: NonoCell = tool == .fill ? .filled : .crossed
        let target: NonoCell = current == mark ? .unknown : mark
        // Clearing only clears the same kind of mark; marking only marks blanks,
        // except that the first square can switch a cross to a fill and back.
        let replaces: NonoCell = target == .unknown ? mark : .unknown
        stroke = Stroke(start: i, target: target, replaces: replaces, before: save.cells)
        activeCell = i
        var cells = save.cells
        cells[i] = target
        save.cells = cells
    }

    func continueStroke(to i: Int) {
        guard var s = stroke, acceptsInput else { return }
        let w = puzzle.width
        let (r0, c0) = (s.start / w, s.start % w)
        var (r, c) = (i / w, i % w)
        if s.horizontal == nil, i != s.start {
            s.horizontal = abs(c - c0) >= abs(r - r0)
            stroke = s
        }
        // Stay on the row or column the drag started along.
        if let horizontal = s.horizontal {
            if horizontal { r = r0 } else { c = c0 }
        }
        let end = r * w + c
        activeCell = end
        var cells = s.before
        let path: [Int]
        if s.horizontal == true {
            path = (min(c0, c)...max(c0, c)).map { r0 * w + $0 }
        } else if s.horizontal == false {
            path = (min(r0, r)...max(r0, r)).map { $0 * w + c0 }
        } else {
            path = [s.start]
        }
        for p in path where p == s.start || cells[p] == s.replaces {
            cells[p] = s.target
        }
        save.cells = cells
    }

    func endStroke() {
        guard let s = stroke else { return }
        stroke = nil
        activeCell = nil
        guard s.before != save.cells else { return }
        save.undoStack.append(s.before)
        if save.undoStack.count > Self.maxUndo { save.undoStack.removeFirst() }
        hint = nil
        if showMistakes {
            let newlyWrong = save.cells.indices.filter { isWrong($0) && s.before[$0] != save.cells[$0] }
            save.mistakes += newlyWrong.count
        }
        if isComplete { complete() }
        persist()
    }

    private func commit(_ cells: [NonoCell]) {
        save.undoStack.append(save.cells)
        if save.undoStack.count > Self.maxUndo { save.undoStack.removeFirst() }
        save.cells = cells
        if isComplete { complete() }
        persist()
    }

    func undo() {
        guard canUndo, let previous = save.undoStack.popLast() else { return }
        hint = nil
        save.cells = previous
        persist()
    }

    /// Clears the board and resets the clock.
    func restart() {
        stopClock()
        hint = nil
        save.cells = [NonoCell](repeating: .unknown, count: puzzle.cellCount)
        save.undoStack = []
        save.elapsed = 0
        save.mistakes = 0
        isPaused = false
        start()
        persist()
    }

    private func complete() {
        stopClock()
        save.undoStack = []
        hint = nil
        // Cross the leftover blanks so the finished picture is clean.
        save.cells = save.cells.map { $0 == .filled ? .filled : .crossed }
        if persists && !puzzle.isRandom {
            NonogramRecords.record(puzzle.id, time: save.elapsed)
        }
    }

    // MARK: - Hints

    func requestHint() {
        guard acceptsInput else { return }
        let wrong = Set(save.cells.indices.filter { isWrong($0) })
        if !wrong.isEmpty {
            hint = NonogramHint(
                text: wrong.count == 1 ? "This square is marked wrong." : "These \(wrong.count) squares are marked wrong.",
                mistakes: wrong
            )
            return
        }
        guard let d = NonogramSolver.bestDeduction(puzzle, cells: save.cells) else {
            hint = NonogramHint(text: "Nothing left to work out.")
            return
        }
        let clue = puzzle.clues(for: d.line)
        let clueText = clue.isEmpty ? "0" : clue.map(String.init).joined(separator: " ")
        var parts: [String] = []
        if !d.fill.isEmpty { parts.append("\(d.fill.count) to fill") }
        if !d.cross.isEmpty { parts.append("\(d.cross.count) to cross out") }
        hint = NonogramHint(
            text: "\(d.line.name), clue \(clueText): \(parts.joined(separator: " and ")).",
            line: d.line,
            fill: d.fill,
            cross: d.cross
        )
    }

    /// Makes the hinted marks (or clears the hinted mistakes).
    func applyHint() {
        guard acceptsInput, let hint else { return }
        var cells = save.cells
        for i in hint.mistakes { cells[i] = .unknown }
        for i in hint.fill { cells[i] = .filled }
        for i in hint.cross { cells[i] = .crossed }
        self.hint = nil
        commit(cells)
    }

    func dismissHint() { hint = nil }
}

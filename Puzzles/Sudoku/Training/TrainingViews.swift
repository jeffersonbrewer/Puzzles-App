import SwiftUI

private struct LessonGroup: Identifiable {
    let title: String
    let techniques: [Technique]
    var id: String { title }
}

struct TrainingListView: View {
    private let groups: [LessonGroup] = [
        LessonGroup(title: "Basics", techniques: [.hiddenSingle, .nakedSingle]),
        LessonGroup(title: "Intermediate", techniques: [.pointing, .boxLine, .nakedPair, .hiddenPair, .nakedTriple]),
        LessonGroup(title: "Advanced", techniques: [.xWing, .yWing, .xyzWing, .swordfish])
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reading the lessons").font(.headline)
                    Text("Small numbers in a cell are its candidates: the digits that could still go there. Cells are named by row and column, so R3C7 is row 3, column 7. Rows count from the top, columns from the left, and boxes 1-9 run left to right, top to bottom.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            ForEach(groups) { group in
                Section(group.title) {
                    ForEach(group.techniques) { t in
                        NavigationLink {
                            TrainingLessonView(technique: t)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.title).font(.headline)
                                Text(TrainingLesson.lesson(for: t).summary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Training")
    }
}

/// A board position where a technique applies.
struct TrainingExample {
    let givens: [Int]
    let grid: CandidateGrid
    let step: LogicStep
}

enum TrainingExamples {
    /// Walks a puzzle's solving path and returns the first position where
    /// `technique` is the easiest next step (or, failing that, where it applies at all).
    static func example(for technique: Technique, puzzle: [Int]) -> TrainingExample? {
        var grid = CandidateGrid(values: puzzle)
        var fallback: TrainingExample?
        while !grid.isSolved {
            guard let next = LogicSolver.nextStep(grid) else { break }
            if next.technique == technique {
                return TrainingExample(givens: puzzle, grid: grid, step: next)
            }
            if fallback == nil, let any = LogicSolver.find(technique, in: grid) {
                fallback = TrainingExample(givens: puzzle, grid: grid, step: any)
            }
            grid.apply(next)
        }
        return fallback
    }

    static func bankPuzzles(for technique: Technique) -> [[Int]] {
        let own = TrainingBank.puzzles[technique] ?? []
        let all = own.isEmpty ? TrainingBank.puzzles.values.flatMap { $0 } : own
        return all.map(Sudoku.parse)
    }

    /// Example number `index`: from the built-in bank first, then freshly generated.
    static func load(_ technique: Technique, index: Int) -> TrainingExample? {
        let bank = bankPuzzles(for: technique)
        if index < bank.count, let ex = example(for: technique, puzzle: bank[index]) {
            return ex
        }
        for _ in 0..<300 {
            let (givens, _) = SudokuGenerator.makeMinimal(minimumClues: 17)
            if let ex = example(for: technique, puzzle: givens) { return ex }
        }
        return nil
    }
}

struct TrainingLessonView: View {
    let technique: Technique

    private enum Stage: Int { case find, pattern, result, applied }

    @State private var example: TrainingExample?
    @State private var stage: Stage = .find
    @State private var index = 0
    @State private var loading = false
    @State private var failed = false

    private var lesson: TrainingLesson { .lesson(for: technique) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(lesson.summary)
                    .font(.body)

                VStack(alignment: .leading, spacing: 8) {
                    Text("What to look for").font(.headline)
                    ForEach(Array(lesson.lookFor.enumerated()), id: \.offset) { n, line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(n + 1).")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                            Text(line).font(.callout)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Why it works").font(.headline)
                    Text(lesson.whyItWorks).font(.callout).foregroundStyle(.secondary)
                }

                Divider()
                Text("Example \(index + 1)").font(.title3.weight(.semibold))
                exampleSection
            }
            .padding()
        }
        .navigationTitle(technique.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { if example == nil { await load() } }
    }

    @ViewBuilder
    private var exampleSection: some View {
        if let example {
            let grid = displayedGrid(example)
            SudokuBoardView(
                values: grid.values,
                givens: example.givens,
                notes: grid.candidates,
                highlightPeers: false,
                step: stage == .find || stage == .applied ? nil : example.step,
                showStepResult: stage == .result
            )
            stageCard(example)
        } else if failed {
            Text("Couldn't find an example this time. Try again.")
                .foregroundStyle(.secondary)
            Button("Try again") { Task { await load() } }
        } else {
            HStack {
                ProgressView()
                Text("Finding an example...").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    private func displayedGrid(_ example: TrainingExample) -> CandidateGrid {
        guard stage == .applied else { return example.grid }
        var g = example.grid
        g.apply(example.step)
        return g
    }

    private func stageCard(_ example: TrainingExample) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            switch stage {
            case .find:
                Label("Your turn", systemImage: "magnifyingglass").font(.headline)
                Text(lesson.prompt).font(.callout)
                Button("Show the pattern") { withAnimation { stage = .pattern } }
                    .buttonStyle(.borderedProminent)
            case .pattern:
                Label("The pattern", systemImage: "sparkles").font(.headline)
                    .foregroundStyle(Theme.patternCandidate)
                Text(example.step.explanation).font(.callout)
                Button("Show the result") { withAnimation { stage = .result } }
                    .buttonStyle(.borderedProminent)
            case .result:
                Label("The result", systemImage: "checkmark.circle").font(.headline)
                    .foregroundStyle(Theme.placement)
                Text(resultText(example.step)).font(.callout)
                legend
                Button("Apply it") { withAnimation { stage = .applied } }
                    .buttonStyle(.borderedProminent)
            case .applied:
                Label("Applied", systemImage: "checkmark.seal").font(.headline)
                    .foregroundStyle(Theme.placement)
                Text("The board now reflects the deduction. Try another example to practise spotting it.")
                    .font(.callout)
            }
            HStack {
                if stage != .find {
                    Button("Start over") { withAnimation { stage = .find } }
                }
                Spacer()
                Button("Another example") {
                    index += 1
                    Task { await load() }
                }
                .disabled(loading)
            }
            .font(.callout)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendDot(Theme.patternCell, "Pattern")
            legendDot(Theme.elimination, "Removed")
            legendDot(Theme.placement, "Placed")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
        }
    }

    private func resultText(_ step: LogicStep) -> String {
        if let p = step.placements.first {
            return "Place \(p.digit) in \(Sudoku.cellName(p.cell))."
        }
        let byDigit = Dictionary(grouping: step.eliminations, by: { $0.digit })
        let parts = byDigit.keys.sorted().map { d in
            "\(d) from \(Sudoku.cellList(byDigit[d]!.map { $0.cell }))"
        }
        return "Remove " + Sudoku.listText(parts) + "."
    }

    private func load() async {
        loading = true
        failed = false
        example = nil
        stage = .find
        let t = technique, i = index
        let result = await Task.detached(priority: .userInitiated) {
            TrainingExamples.load(t, index: i)
        }.value
        example = result
        failed = result == nil
        loading = false
    }
}

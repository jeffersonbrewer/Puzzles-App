import SwiftUI

struct NonogramTrainingListView: View {
    var body: some View {
        List {
            Section("Basics") {
                ForEach(NonogramLesson.basics) { row($0) }
                NavigationLink {
                    NonogramPracticeView()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Practice Puzzle").font(.headline)
                        Text("A small puzzle to try what you've learned, with hints if you need them.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            Section("Solving Tricks") {
                ForEach(NonogramLesson.more) { row($0) }
            }
        }
        .themedBackground()
        .navigationTitle("Lessons")
    }

    private func row(_ lesson: NonogramLesson) -> some View {
        NavigationLink {
            NonogramLessonView(lesson: lesson)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title).font(.headline)
                Text(lesson.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

/// The starter puzzle from the lessons. Not saved, so it never replaces a game in progress.
struct NonogramPracticeView: View {
    @StateObject private var game = NonogramGame(puzzle: NonogramLibrary.starter, persists: false)

    var body: some View {
        NonogramGameView(game: game, title: "Practice", onNext: nil)
    }
}

struct NonogramLessonView: View {
    @Environment(\.palette) private var palette
    let lesson: NonogramLesson

    private enum Stage { case find, result, applied }

    @State private var index = 0
    @State private var stage: Stage = .find

    private var example: NonogramLineExample { lesson.examples[index % lesson.examples.count] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(lesson.summary).font(.body)

                VStack(alignment: .leading, spacing: 8) {
                    Text("What to look for").font(.headline)
                    ForEach(Array(lesson.lookFor.enumerated()), id: \.offset) { n, line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(n + 1).")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(palette.accent)
                            Text(line).font(.callout)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Why it works").font(.headline)
                    Text(lesson.whyItWorks).font(.callout).foregroundStyle(.secondary)
                }

                Divider()
                Text("Example \(index % lesson.examples.count + 1) of \(lesson.examples.count)")
                    .font(.title3.weight(.semibold))
                NonogramLineStrip(example: example, stage: stageValue)
                stageCard
            }
            .padding()
        }
        .themedBackground()
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var stageValue: NonogramLineStrip.Stage {
        switch stage {
        case .find: return .start
        case .result: return .result
        case .applied: return .applied
        }
    }

    private var stageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch stage {
            case .find:
                Label("Your turn", systemImage: "magnifyingglass").font(.headline)
                Text(lesson.prompt).font(.callout)
                Button("Show the answer") { withAnimation { stage = .result } }
                    .buttonStyle(.borderedProminent)
            case .result:
                Label("The answer", systemImage: "checkmark.circle").font(.headline)
                    .foregroundStyle(Theme.placement)
                Text(example.explanation).font(.callout)
                legend
                Button("Apply it") { withAnimation { stage = .applied } }
                    .buttonStyle(.borderedProminent)
            case .applied:
                Label("Applied", systemImage: "checkmark.seal").font(.headline)
                    .foregroundStyle(Theme.placement)
                Text("Squares left blank could still go either way. In a puzzle, the crossing columns usually settle them.")
                    .font(.callout)
            }
            HStack {
                if stage != .find {
                    Button("Start over") { withAnimation { stage = .find } }
                }
                Spacer()
                Button("Another example") {
                    withAnimation {
                        index += 1
                        stage = .find
                    }
                }
            }
            .font(.callout)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendDot(Theme.placement, "Must be filled")
            legendDot(Theme.elimination, "Must be empty")
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
}

/// A single row with its clue, used in the lessons.
struct NonogramLineStrip: View {
    @Environment(\.palette) private var palette
    enum Stage { case start, result, applied }

    let example: NonogramLineExample
    let stage: Stage

    var body: some View {
        let start = example.cells
        let solved = example.solved
        let shown = stage == .applied ? solved : start
        let puzzle = NonogramPuzzle(id: "lesson", name: "", width: start.count, height: 1, solution: solved.map { $0 == .filled })
        let fill: Set<Int> = stage == .result ? Set(start.indices.filter { start[$0] == .unknown && solved[$0] == .filled }) : []
        let cross: Set<Int> = stage == .result ? Set(start.indices.filter { start[$0] == .unknown && solved[$0] == .crossed }) : []
        GeometryReader { geo in
            let clueWidth: CGFloat = 70
            let cell = min(40, floor((geo.size.width - clueWidth) / CGFloat(start.count)))
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                Text(example.clue.isEmpty ? "0" : example.clue.map(String.init).joined(separator: " "))
                    .font(.system(size: max(12, cell * 0.5), weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: clueWidth - 6, alignment: .trailing)
                NonogramGridCanvas(puzzle: puzzle, cells: shown, cell: cell, hintFill: fill, hintCross: cross)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 44)
        .accessibilityElement()
        .accessibilityLabel("Clue \(example.clue.isEmpty ? "0" : example.clue.map(String.init).joined(separator: " ")), \(example.start.count) squares")
    }
}

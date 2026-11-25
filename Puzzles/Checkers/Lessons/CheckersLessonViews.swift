import SwiftUI

struct CheckersLessonListView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reading the lessons").font(.headline)
                    Text("You play red from the bottom of the board. Squares are named like a chessboard: letters a to h from the left, numbers 1 to 8 from your side, so c3 is the third column, third row up. Each lesson ends with a position to try on a real board.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            ForEach(CheckersLessons.groups) { group in
                Section(group.title) {
                    ForEach(group.lessons) { lesson in
                        NavigationLink {
                            CheckersLessonView(lesson: lesson)
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
            }
        }
        .themedBackground()
        .navigationTitle("Learn Checkers")
    }
}

struct CheckersLessonView: View {
    @Environment(\.palette) private var palette
    let lesson: CheckersLesson

    private enum Stage: Equatable {
        case playing
        case wrong
        case solved
    }

    @State private var index = 0
    @State private var board: Checkers
    @State private var picker = CheckersMovePicker()
    @State private var stage: Stage = .playing
    @State private var lineStep = 0
    @State private var lastMove: CheckersMove?
    @State private var shown: CheckersMove?
    @State private var notice: String?
    @State private var isAnimating = false

    init(lesson: CheckersLesson) {
        self.lesson = lesson
        _board = State(initialValue: lesson.exercises[0].board)
    }

    private var exercise: CheckersExercise { lesson.exercises[index] }
    private var legal: [CheckersMove] { board.turn == .player ? board.legalMoves() : [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(lesson.summary).font(.body)

                VStack(alignment: .leading, spacing: 8) {
                    Text("How it works").font(.headline)
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
                    Text("Why it matters").font(.headline)
                    Text(lesson.whyItWorks).font(.callout).foregroundStyle(.secondary)
                }

                Divider()
                Text(lesson.exercises.count > 1 ? "Try it (\(index + 1) of \(lesson.exercises.count))" : "Try it")
                    .font(.title3.weight(.semibold))
                CheckersBoardView(
                    board: board,
                    selectedPath: picker.path,
                    targets: picker.targets(legal),
                    lastMove: lastMove,
                    hint: shown,
                    showCoordinates: true,
                    onTap: { tap($0) }
                )
                .allowsHitTesting(stage == .playing && !isAnimating)
                stageCard
            }
            .padding()
        }
        .themedBackground()
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Card under the board

    private var stageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch stage {
            case .playing:
                Label("Your turn", systemImage: "hand.point.up.left").font(.headline)
                Text(exercise.prompt).font(.callout)
                if let notice {
                    Text(notice).font(.callout).foregroundStyle(Theme.patternCandidate)
                }
                Button("Show me") { showAnswer() }
                    .buttonStyle(.bordered)
                    .disabled(isAnimating)
            case .wrong:
                Label("Not quite", systemImage: "arrow.uturn.backward.circle").font(.headline)
                    .foregroundStyle(Theme.wrongText)
                Text(exercise.tip).font(.callout)
                Button("Try again") { reset() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnimating)
            case .solved:
                Label("Well done", systemImage: "checkmark.seal").font(.headline)
                    .foregroundStyle(Theme.placement)
                Text(exercise.success).font(.callout)
            }
            HStack {
                if stage != .playing || lastMove != nil {
                    Button("Start over") { reset() }
                        .disabled(isAnimating)
                }
                Spacer()
                if lesson.exercises.count > 1 {
                    Button(index + 1 < lesson.exercises.count ? "Next example" : "First example") {
                        index = (index + 1) % lesson.exercises.count
                        reset()
                    }
                    .disabled(isAnimating)
                }
            }
            .font(.callout)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Playing

    private func reset() {
        board = exercise.board
        picker.clear()
        stage = .playing
        lineStep = 0
        lastMove = nil
        shown = nil
        notice = nil
    }

    private func tap(_ square: Int) {
        guard stage == .playing, !isAnimating else { return }
        switch picker.tap(square, board: board, legal: legal) {
        case .completed(let move):
            judge(move)
        case .mustJump:
            notice = "You have a jump, and jumps are required."
        case .blocked:
            notice = "That piece has nowhere to go."
        case .selected, .extended:
            notice = nil
        case .none:
            break
        }
    }

    private func isCorrect(_ move: CheckersMove) -> Bool {
        switch exercise.goal {
        case .anyMove:
            return true
        case .oneOf(let answers):
            return answers.contains(move.notation)
        case .line(let line):
            return lineStep < line.count && line[lineStep] == move.notation
        case .safeMove:
            return !board.applying(move).hasCapture(for: .computer)
        case .winningMove:
            return board.applying(move).legalMoves().isEmpty
        }
    }

    private func judge(_ move: CheckersMove) {
        let correct = isCorrect(move)
        shown = nil
        notice = nil
        Task {
            await animate(move)
            if !correct {
                // Show what goes wrong: the computer takes anything it can.
                if let reply = board.legalMoves().max(by: { $0.captures.count < $1.captures.count }), reply.isCapture {
                    try? await Task.sleep(for: .milliseconds(350))
                    await animate(reply)
                }
                stage = .wrong
                return
            }
            if case .line(let line) = exercise.goal {
                lineStep += 1
                if lineStep < line.count, let reply = board.move(line[lineStep]) {
                    try? await Task.sleep(for: .milliseconds(450))
                    await animate(reply)
                    lineStep += 1
                }
                if lineStep < line.count {
                    notice = "The computer had to jump. Your move."
                    return
                }
            }
            stage = .solved
        }
    }

    private func animate(_ move: CheckersMove) async {
        isAnimating = true
        let steps = board.animationSteps(move)
        for (i, step) in steps.enumerated() {
            withAnimation(.easeInOut(duration: 0.22)) { board = step }
            if i < steps.count - 1 { try? await Task.sleep(for: .milliseconds(260)) }
        }
        lastMove = move
        try? await Task.sleep(for: .milliseconds(150))
        isAnimating = false
    }

    private func showAnswer() {
        picker.clear()
        let moves = legal
        switch exercise.goal {
        case .anyMove:
            shown = moves.first
        case .oneOf(let answers):
            shown = answers.lazy.compactMap { board.move($0) }.first
        case .line(let line):
            shown = lineStep < line.count ? board.move(line[lineStep]) : nil
        case .safeMove:
            shown = moves.first { !board.applying($0).hasCapture(for: .computer) }
        case .winningMove:
            shown = moves.first { board.applying($0).legalMoves().isEmpty }
        }
        if shown != nil { notice = "Move the outlined piece along the outlined squares." }
    }
}

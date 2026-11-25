import SwiftUI

/// Lists the FreeCell and Spider lessons, like Sudoku's Training list.
struct SolitaireLessonListView: View {
    var body: some View {
        List {
            Section {
                Text("Each lesson explains one idea, then gives you a small board to try it on. Make the moves yourself, or tap Show me.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
            Section("FreeCell") {
                ForEach(FreeCellLesson.all) { lesson in
                    NavigationLink {
                        FreeCellLessonView(lesson: lesson)
                    } label: {
                        LessonRow(text: lesson.text)
                    }
                }
            }
            Section("Spider") {
                ForEach(SpiderLesson.all) { lesson in
                    NavigationLink {
                        SpiderLessonView(lesson: lesson)
                    } label: {
                        LessonRow(text: lesson.text)
                    }
                }
            }
        }
        .themedBackground()
        .navigationTitle("How to Play")
    }
}

private struct LessonRow: View {
    let text: LessonText

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text.title).font(.headline)
            Text(text.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

/// The explanation at the top of a lesson.
private struct LessonIntro: View {
    @Environment(\.palette) private var palette
    let text: LessonText

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(text.summary).font(.body)

            VStack(alignment: .leading, spacing: 8) {
                Text("How it works").font(.headline)
                ForEach(Array(text.rules.enumerated()), id: \.offset) { n, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(n + 1).")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.accent)
                        Text(line).font(.callout)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Tips").font(.headline)
                Text(text.tips).font(.callout).foregroundStyle(.secondary)
            }

            Divider()
            Text("Practice").font(.title3.weight(.semibold))
        }
    }
}

/// The card under the practice board: the task, then the result.
private struct LessonPracticeCard: View {
    @Environment(\.palette) private var palette
    let text: LessonText
    let isDone: Bool
    let showMeText: String?
    let onShowMe: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isDone {
                Label("Nicely done", systemImage: "checkmark.seal").font(.headline)
                    .foregroundStyle(Theme.placement)
                Text(text.success).font(.callout)
            } else {
                Label("Your turn", systemImage: "hand.tap").font(.headline)
                Text(text.prompt).font(.callout)
                if let showMeText {
                    Label(showMeText, systemImage: "lightbulb.fill")
                        .font(.callout)
                        .foregroundStyle(Theme.patternCandidate)
                }
            }
            HStack {
                if !isDone {
                    Button("Show me", action: onShowMe)
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
                Button("Start over", action: onReset)
            }
            .font(.callout)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - FreeCell

struct FreeCellLessonView: View {
    let lesson: FreeCellLesson
    @StateObject private var game: FreeCellGame
    @State private var isDone = false

    init(lesson: FreeCellLesson) {
        self.lesson = lesson
        _game = StateObject(wrappedValue: FreeCellGame(lesson: lesson.board))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LessonIntro(text: lesson.text)
                FreeCellBoardView(game: game)
                    .frame(height: 330)
                    .allowsHitTesting(!isDone)
                LessonPracticeCard(
                    text: lesson.text,
                    isDone: isDone,
                    showMeText: game.hint?.text,
                    onShowMe: showMe,
                    onReset: reset
                )
            }
            .padding()
        }
        .themedBackground()
        .navigationTitle(lesson.text.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { game.start() }
        .onChange(of: game.board) { _, board in
            if lesson.goal(board) { withAnimation { isDone = true } }
        }
    }

    /// Highlights the next move of the solution, if the player is still on its path.
    private func showMe() {
        var board = lesson.board
        for move in lesson.solution {
            if board == game.board {
                game.show(hint: move)
                return
            }
            board.apply(move)
        }
        reset()
        if let first = lesson.solution.first { game.show(hint: first) }
    }

    private func reset() {
        isDone = false
        game.restart()
    }
}

// MARK: - Spider

struct SpiderLessonView: View {
    let lesson: SpiderLesson
    @StateObject private var game: SpiderGame
    @State private var isDone = false

    init(lesson: SpiderLesson) {
        self.lesson = lesson
        _game = StateObject(wrappedValue: SpiderGame(lesson: lesson.board))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LessonIntro(text: lesson.text)
                SpiderBoardView(game: game)
                    .frame(height: 360)
                    .allowsHitTesting(!isDone)
                LessonPracticeCard(
                    text: lesson.text,
                    isDone: isDone,
                    showMeText: game.hint?.text,
                    onShowMe: showMe,
                    onReset: reset
                )
            }
            .padding()
        }
        .themedBackground()
        .navigationTitle(lesson.text.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { game.start() }
        .onChange(of: game.board) { _, board in
            if lesson.goal(board) { withAnimation { isDone = true } }
        }
    }

    private func showMe() {
        var board = lesson.board
        for step in lesson.solution {
            if board == game.board {
                game.show(hint: step)
                return
            }
            switch step {
            case .move(let move): board.apply(move)
            case .deal: board.deal()
            }
        }
        reset()
        if let first = lesson.solution.first { game.show(hint: first) }
    }

    private func reset() {
        isDone = false
        game.restart()
    }
}

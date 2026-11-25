import SwiftUI

/// Nonograms' landing screen: continue, picture sets, random puzzles,
/// lessons and settings.
struct NonogramsHomeView: View {
    @Environment(\.palette) private var palette
    @State private var saved: NonogramSave?
    @State private var game: NonogramGame?
    @State private var showGame = false
    @State private var solved = NonogramRecords.solved
    @AppStorage(NonogramSettingsKey.showMistakes) private var showMistakes = false

    var body: some View {
        List {
            if let saved, !saved.isComplete {
                Section {
                    Button {
                        game?.retire()
                        game = NonogramGame(restoring: saved)
                        showGame = true
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                                .foregroundStyle(palette.accent)
                            VStack(alignment: .leading) {
                                Text("Continue").font(.headline)
                                Text("\(NonogramPack.title(for: saved.puzzle)) · \(formatTime(saved.elapsed))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section("Pictures") {
                ForEach(NonogramPack.allCases) { pack in
                    NavigationLink {
                        NonogramPackView(pack: pack)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(pack.title).font(.headline)
                                Spacer()
                                Text("\(pack.puzzles.filter { solved.contains($0.id) }.count) of \(pack.puzzles.count)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Text(pack.blurb).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                ForEach(NonogramPack.allCases) { pack in
                    Button {
                        play(NonogramSolver.random(size: pack.size))
                    } label: {
                        HStack {
                            Text("Random \(pack.title)").font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                Text("Random")
            } footer: {
                Text("A new pattern every time. No picture, just logic, and never any guessing.")
            }

            Section {
                NavigationLink {
                    NonogramTrainingListView()
                } label: {
                    Label("Lessons", systemImage: "graduationcap")
                }
            } footer: {
                Text("How to play, and the tricks for working out every line.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                    AppearancePicker()
                }
                .padding(.vertical, 4)
                NavigationLink {
                    ThemeSettingsView()
                } label: {
                    ThemeColorRow()
                }
                Toggle("Show mistakes as you play", isOn: $showMistakes)
            } header: {
                Text("Settings")
            } footer: {
                Text("The numbers by each row and column give the runs of filled squares in that line, in order. Fill squares to reveal the picture, and cross out the ones that must stay empty.")
            }
        }
        .themedBackground()
        .navigationTitle("Nonograms")
        .onAppear(perform: reload)
        .nonogramPlayer(game: $game, isShowing: $showGame)
        .onChange(of: showGame) { _, isShowing in
            if !isShowing { reload() }
        }
    }

    private func reload() {
        saved = NonogramGame.loadSaved()
        solved = NonogramRecords.solved
    }

    private func play(_ puzzle: NonogramPuzzle) {
        game?.retire()
        game = NonogramGame(puzzle: puzzle)
        showGame = true
    }
}

/// One picture set: a tile per puzzle, showing the picture once it's solved.
struct NonogramPackView: View {
    @Environment(\.palette) private var palette
    let pack: NonogramPack
    @State private var game: NonogramGame?
    @State private var showGame = false
    @State private var solved = NonogramRecords.solved
    @State private var savedID: String?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(pack.puzzles.enumerated()), id: \.element.id) { n, puzzle in
                    Button {
                        open(puzzle)
                    } label: {
                        tile(n: n, puzzle: puzzle)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .themedBackground()
        .navigationTitle(pack.title)
        .onAppear(perform: reload)
        .nonogramPlayer(game: $game, isShowing: $showGame)
        .onChange(of: showGame) { _, isShowing in
            if !isShowing { reload() }
        }
    }

    private func tile(n: Int, puzzle: NonogramPuzzle) -> some View {
        let isSolved = solved.contains(puzzle.id)
        return VStack(spacing: 6) {
            ZStack {
                if isSolved {
                    NonogramThumbnail(puzzle: puzzle, size: 56)
                } else {
                    Text("\(n + 1)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.accent)
                }
            }
            .frame(width: 64, height: 64)
            Text(isSolved ? puzzle.name : (savedID == puzzle.id ? "In progress" : "No. \(n + 1)"))
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            Text(NonogramRecords.bestTime(puzzle.id).map { "Best \(formatTime($0))" } ?? " ")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func reload() {
        solved = NonogramRecords.solved
        let saved = NonogramGame.loadSaved()
        savedID = (saved?.isComplete == false) ? saved?.puzzle.id : nil
    }

    private func open(_ puzzle: NonogramPuzzle) {
        game?.retire()
        if let saved = NonogramGame.loadSaved(), saved.puzzle.id == puzzle.id, !saved.isComplete {
            game = NonogramGame(restoring: saved)
        } else {
            game = NonogramGame(puzzle: puzzle)
        }
        showGame = true
    }
}

extension View {
    /// Pushes the game screen for `game` when `isShowing` is true, with
    /// "Next puzzle" wired up.
    func nonogramPlayer(game: Binding<NonogramGame?>, isShowing: Binding<Bool>) -> some View {
        navigationDestination(isPresented: isShowing) {
            if let current = game.wrappedValue {
                NonogramGameView(
                    game: current,
                    title: NonogramPack.title(for: current.puzzle),
                    onNext: nonogramNextAction(after: current, game: game)
                )
                // A fresh identity per puzzle, so a new one starts its own clock.
                .id(ObjectIdentifier(current))
            }
        }
    }
}

/// Replaces the current game with the next puzzle, or nil if there isn't one.
@MainActor
private func nonogramNextAction(after current: NonogramGame, game: Binding<NonogramGame?>) -> (() -> Void)? {
    guard NonogramPack.hasNext(after: current.puzzle) else { return nil }
    return {
        guard let next = NonogramPack.next(after: current.puzzle) else { return }
        current.retire()
        game.wrappedValue = NonogramGame(puzzle: next)
    }
}

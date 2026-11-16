import SwiftUI

/// Sudoku's landing screen: continue, start a new game, training and settings.
struct SudokuHomeView: View {
    @Environment(\.palette) private var palette
    @State private var saved: SudokuSave?
    @State private var game: SudokuGame?
    @State private var showGame = false
    @State private var generating: Difficulty?

    @AppStorage(SudokuSettingsKey.showMistakes) private var showMistakes = true
    @AppStorage(SudokuSettingsKey.highlightPeers) private var highlightPeers = true
    @AppStorage(SudokuSettingsKey.autoRemoveNotes) private var autoRemoveNotes = true

    var body: some View {
        List {
            if let saved, !saved.isComplete {
                Section {
                    Button {
                        game = SudokuGame(restoring: saved)
                        showGame = true
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                                .foregroundStyle(palette.accent)
                            VStack(alignment: .leading) {
                                Text("Continue").font(.headline)
                                Text("\(saved.puzzle.difficulty.title) · \(formatTime(saved.elapsed))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section("New game") {
                ForEach(Difficulty.allCases) { d in
                    Button {
                        startNew(d)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.title).font(.headline)
                                Text(d.blurb).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if generating == d {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .disabled(generating != nil)
                }
            }

            Section {
                NavigationLink {
                    TrainingListView()
                } label: {
                    Label("Training", systemImage: "graduationcap")
                }
            } footer: {
                Text("Step-by-step lessons for singles, pairs, X-Wings, Y-Wings and more.")
            }

            Section("Settings") {
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
                Toggle("Highlight row, column and box", isOn: $highlightPeers)
                Toggle("Remove notes when placing a number", isOn: $autoRemoveNotes)
            }
        }
        .navigationTitle("Sudoku")
        .onAppear { saved = SudokuGame.loadSaved() }
        .navigationDestination(isPresented: $showGame) {
            if let game {
                SudokuGameView(game: game) { d in
                    showGame = false
                    startNew(d)
                }
            }
        }
        .onChange(of: showGame) { _, isShowing in
            if !isShowing { saved = SudokuGame.loadSaved() }
        }
    }

    private func startNew(_ difficulty: Difficulty) {
        generating = difficulty
        Task {
            let puzzle = await Task.detached(priority: .userInitiated) {
                SudokuGenerator.generate(difficulty)
            }.value
            game = SudokuGame(puzzle: puzzle)
            generating = nil
            showGame = true
        }
    }
}

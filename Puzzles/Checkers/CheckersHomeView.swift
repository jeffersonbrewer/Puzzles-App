import SwiftUI

/// Checkers' landing screen: continue, new game against the computer, lessons and settings.
struct CheckersHomeView: View {
    @Environment(\.palette) private var palette
    @State private var saved: CheckersSave?
    @State private var game: CheckersGame?
    @State private var showGame = false

    @AppStorage(CheckersSettingsKey.playerFirst) private var playerFirst = true
    @AppStorage(CheckersSettingsKey.showMovable) private var showMovable = true

    var body: some View {
        List {
            if let saved, saved.outcome == nil {
                Section {
                    Button {
                        game = CheckersGame(restoring: saved)
                        showGame = true
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                                .foregroundStyle(palette.accent)
                            VStack(alignment: .leading) {
                                Text("Continue").font(.headline)
                                Text("\(saved.difficulty.title) · \(saved.board.count(.player)) vs \(saved.board.count(.computer)) · \(formatTime(saved.elapsed))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section {
                ForEach(CheckersDifficulty.allCases) { d in
                    Button {
                        startNew(d)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.title).font(.headline)
                                Text(d.blurb).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                Toggle("You move first", isOn: $playerFirst)
            } header: {
                Text("New game vs computer")
            }

            Section {
                NavigationLink {
                    CheckersLessonListView()
                } label: {
                    Label("Learn to play", systemImage: "graduationcap")
                }
            } footer: {
                Text("Short lessons on moving, jumps, kings, winning and a few tricks, each with a position to try.")
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
                Toggle("Show pieces that can move", isOn: $showMovable)
            } header: {
                Text("Settings")
            } footer: {
                Text("Tap a piece, then tap where it should go. For a multiple jump, tap each landing square in turn. Jumps are required.")
            }
        }
        .themedBackground()
        .navigationTitle("Checkers")
        .onAppear { saved = CheckersGame.loadSaved() }
        .navigationDestination(isPresented: $showGame) {
            if let game {
                // A fresh identity per game, so a new game starts its own clock.
                CheckersGameView(game: game, onNewGame: startNew)
                    .id(ObjectIdentifier(game))
            }
        }
        .onChange(of: showGame) { _, isShowing in
            if !isShowing { saved = CheckersGame.loadSaved() }
        }
    }

    private func startNew(_ difficulty: CheckersDifficulty) {
        game?.retire()
        game = CheckersGame(difficulty: difficulty, playerFirst: playerFirst)
        showGame = true
    }
}

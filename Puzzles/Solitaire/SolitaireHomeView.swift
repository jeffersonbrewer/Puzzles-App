import SwiftUI

/// Solitaire's landing screen: continue, start a new game and settings.
struct SolitaireHomeView: View {
    @Environment(\.palette) private var palette
    @State private var saved: SolitaireSave?
    @State private var game: SolitaireGame?
    @State private var showGame = false

    var body: some View {
        List {
            if let saved, !saved.board.isWon {
                Section {
                    Button {
                        game = SolitaireGame(restoring: saved)
                        showGame = true
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                                .foregroundStyle(palette.accent)
                            VStack(alignment: .leading) {
                                Text("Continue").font(.headline)
                                Text("Draw \(saved.drawCount) · \(formatTime(saved.elapsed))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section("New game") {
                newGameRow(1, blurb: "Turn one card at a time. Easier to win.")
                newGameRow(3, blurb: "Turn three at a time. The classic challenge.")
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
            } header: {
                Text("Settings")
            } footer: {
                Text("Tap a card to send it to its best spot, or drag it anywhere it fits. Build columns down in alternating colors and foundations up from the ace.")
            }
        }
        .themedBackground()
        .navigationTitle("Solitaire")
        .onAppear { saved = SolitaireGame.loadSaved() }
        .navigationDestination(isPresented: $showGame) {
            if let game {
                // A fresh identity per deal, so a new game starts its own clock.
                SolitaireGameView(game: game, onNewGame: startNew)
                    .id(ObjectIdentifier(game))
            }
        }
        .onChange(of: showGame) { _, isShowing in
            if !isShowing { saved = SolitaireGame.loadSaved() }
        }
    }

    private func newGameRow(_ drawCount: Int, blurb: String) -> some View {
        Button {
            startNew(drawCount)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Draw \(drawCount)").font(.headline)
                    Text(blurb).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }

    private func startNew(_ drawCount: Int) {
        game?.retire()
        game = SolitaireGame(drawCount: drawCount)
        showGame = true
    }
}

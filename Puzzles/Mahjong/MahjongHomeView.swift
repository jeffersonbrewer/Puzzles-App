import SwiftUI

/// Mahjong's landing screen: continue, start a new game and settings.
struct MahjongHomeView: View {
    @Environment(\.palette) private var palette
    @AppStorage(MahjongSettings.dimBlockedKey) private var dimBlocked = true
    @State private var saved: MahjongSave?
    @State private var game: MahjongGame?
    @State private var showGame = false

    var body: some View {
        List {
            if let saved, !saved.board.isCleared {
                Section {
                    Button {
                        game = MahjongGame(restoring: saved)
                        showGame = true
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                                .foregroundStyle(palette.accent)
                            VStack(alignment: .leading) {
                                Text("Continue").font(.headline)
                                Text("\(saved.board.layout.name) · \(saved.board.remaining) tiles left · \(formatTime(saved.elapsed))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            Section("New game") {
                ForEach(MahjongLayout.all) { layout in
                    newGameRow(layout)
                }
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
                Toggle("Shade blocked tiles", isOn: $dimBlocked)
            } header: {
                Text("Settings")
            } footer: {
                Text("Clear the board by removing matching pairs. A tile can be taken when nothing is on top of it and its left or right side is open. Any two flowers match, and so do any two seasons. Every deal can be cleared.")
            }
        }
        .themedBackground()
        .navigationTitle("Mahjong")
        .onAppear { saved = MahjongGame.loadSaved() }
        .navigationDestination(isPresented: $showGame) {
            if let game {
                // A fresh identity per deal, so a new game starts its own clock.
                MahjongGameView(game: game, onNewGame: startNew)
                    .id(ObjectIdentifier(game))
            }
        }
        .onChange(of: showGame) { _, isShowing in
            if !isShowing { saved = MahjongGame.loadSaved() }
        }
    }

    private func newGameRow(_ layout: MahjongLayout) -> some View {
        Button {
            startNew(layout)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(layout.name).font(.headline)
                    Text(layout.blurb).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }

    private func startNew(_ layout: MahjongLayout) {
        game?.retire()
        game = MahjongGame(layout: layout)
        showGame = true
    }
}

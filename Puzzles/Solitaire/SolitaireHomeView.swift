import SwiftUI

/// Solitaire's landing screen: continue, new Klondike, FreeCell and Spider
/// games, lessons and settings.
struct SolitaireHomeView: View {
    @Environment(\.palette) private var palette
    @State private var saved: SolitaireSave?
    @State private var savedFreeCell: FreeCellSave?
    @State private var savedSpider: SpiderSave?
    @State private var game: SolitaireGame?
    @State private var freeCell: FreeCellGame?
    @State private var spider: SpiderGame?
    @State private var showGame = false
    @State private var showFreeCell = false
    @State private var showSpider = false

    var body: some View {
        List {
            continueSection

            Section("Klondike") {
                newGameRow("Draw 1", blurb: "Turn one card at a time. Easier to win.") { startNew(1) }
                newGameRow("Draw 3", blurb: "Turn three at a time. The classic challenge.") { startNew(3) }
            }

            Section("FreeCell") {
                newGameRow("New game", blurb: "Every card face up, four free cells. Nearly every deal can be won.") { startFreeCell() }
            }

            Section("Spider") {
                newGameRow("1 Suit", blurb: "All spades. The gentlest way to learn Spider.") { startSpider(1) }
                newGameRow("2 Suits", blurb: "Spades and hearts. A real challenge.") { startSpider(2) }
                newGameRow("4 Suits", blurb: "All four suits. For experts.") { startSpider(4) }
            }

            Section {
                NavigationLink {
                    SolitaireLessonListView()
                } label: {
                    Label("How to play FreeCell and Spider", systemImage: "graduationcap")
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
            } header: {
                Text("Settings")
            } footer: {
                Text("Tap a card to send it to its best spot, or drag it anywhere it fits.")
            }
        }
        .themedBackground()
        .navigationTitle("Solitaire")
        .onAppear(perform: loadSaves)
        .navigationDestination(isPresented: $showGame) {
            if let game {
                // A fresh identity per deal, so a new game starts its own clock.
                SolitaireGameView(game: game, onNewGame: startNew)
                    .id(ObjectIdentifier(game))
            }
        }
        .navigationDestination(isPresented: $showFreeCell) {
            if let freeCell {
                FreeCellGameView(game: freeCell, onNewGame: startFreeCell)
                    .id(ObjectIdentifier(freeCell))
            }
        }
        .navigationDestination(isPresented: $showSpider) {
            if let spider {
                SpiderGameView(game: spider, onNewGame: startSpider)
                    .id(ObjectIdentifier(spider))
            }
        }
        .onChange(of: showGame) { _, isShowing in if !isShowing { loadSaves() } }
        .onChange(of: showFreeCell) { _, isShowing in if !isShowing { loadSaves() } }
        .onChange(of: showSpider) { _, isShowing in if !isShowing { loadSaves() } }
    }

    private func loadSaves() {
        saved = SolitaireGame.loadSaved()
        savedFreeCell = FreeCellGame.loadSaved()
        savedSpider = SpiderGame.loadSaved()
    }

    // MARK: Continue

    @ViewBuilder
    private var continueSection: some View {
        let klondike = saved?.board.isWon == false ? saved : nil
        let freeCellSave = savedFreeCell?.board.isWon == false ? savedFreeCell : nil
        let spiderSave = savedSpider?.board.isWon == false ? savedSpider : nil
        if klondike != nil || freeCellSave != nil || spiderSave != nil {
            Section {
                if let klondike {
                    continueRow("Klondike", detail: "Draw \(klondike.drawCount) · \(formatTime(klondike.elapsed))") {
                        game = SolitaireGame(restoring: klondike)
                        showGame = true
                    }
                }
                if let freeCellSave {
                    continueRow("FreeCell", detail: formatTime(freeCellSave.elapsed)) {
                        freeCell = FreeCellGame(restoring: freeCellSave)
                        showFreeCell = true
                    }
                }
                if let spiderSave {
                    continueRow("Spider", detail: "\(SpiderGame.title(suits: spiderSave.suits)) · \(formatTime(spiderSave.elapsed))") {
                        spider = SpiderGame(restoring: spiderSave)
                        showSpider = true
                    }
                }
            }
        }
    }

    private func continueRow(_ title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(palette.accent)
                VStack(alignment: .leading) {
                    Text("Continue \(title)").font(.headline)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private func newGameRow(_ title: String, blurb: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(blurb).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: Starting games

    private func startNew(_ drawCount: Int) {
        game?.retire()
        game = SolitaireGame(drawCount: drawCount)
        showGame = true
    }

    private func startFreeCell() {
        freeCell?.retire()
        freeCell = FreeCellGame()
        showFreeCell = true
    }

    private func startSpider(_ suits: Int) {
        spider?.retire()
        spider = SpiderGame(suits: suits)
        showSpider = true
    }
}

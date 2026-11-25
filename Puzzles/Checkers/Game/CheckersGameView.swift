import SwiftUI

enum CheckersSettingsKey {
    static let showMovable = "checkers.showMovable"
    static let playerFirst = "checkers.playerFirst"
}

struct CheckersGameView: View {
    @Environment(\.palette) private var palette
    @ObservedObject var game: CheckersGame
    var onNewGame: (CheckersDifficulty) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(CheckersSettingsKey.showMovable) private var showMovable = true
    @State private var confirmRestart = false

    var body: some View {
        VStack(spacing: 12) {
            statusBar
            scoreRow(.computer)
            ZStack {
                CheckersBoardView(
                    board: game.board,
                    selectedPath: game.picker.path,
                    targets: game.targets,
                    lastMove: game.save.lastMove,
                    hint: game.hint,
                    flash: game.flash,
                    movable: showMovable && game.picker.path.isEmpty ? game.movablePieces : [],
                    onTap: { game.tap($0) }
                )
                .opacity(game.isPaused ? 0 : 1)
                if game.isPaused { pausedCard }
            }
            .padding(.horizontal, 10)
            scoreRow(.player)
            messageBar
            Spacer(minLength: 0)
            controls
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedBackground()
        .navigationTitle("Checkers · \(game.difficulty.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { gameMenu }
        }
        .overlay {
            if let outcome = game.outcome, !game.isAnimating { completionCard(outcome) }
        }
        .onAppear { game.start() }
        .onDisappear { game.suspend() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.pause() }
        }
        .confirmationDialog("Start this game over?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Start over", role: .destructive) { game.restart() }
        }
    }

    // MARK: Status

    private var statusBar: some View {
        HStack {
            Label("\(game.save.moves) move\(game.save.moves == 1 ? "" : "s")", systemImage: "hand.tap")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(formatTime(game.elapsed))
                    .font(.system(.body, design: .rounded).monospacedDigit().weight(.semibold))
            }
            Button {
                game.isPaused ? game.resume() : game.pause()
            } label: {
                Image(systemName: game.isPaused ? "play.fill" : "pause.fill")
                    .frame(width: 32, height: 32)
            }
            .disabled(game.isOver)
            .accessibilityLabel(game.isPaused ? "Resume" : "Pause")
        }
        .padding(.horizontal, 16)
    }

    /// Who is who, how many pieces each has, and whose turn it is.
    private func scoreRow(_ side: CheckersSide) -> some View {
        let isTurn = game.board.turn == side && !game.isOver
        return HStack(spacing: 10) {
            PieceView(piece: CheckersPiece(id: -1, side: side), size: 22)
            Text(side == .player ? "You" : "Computer")
                .font(.subheadline.weight(isTurn ? .semibold : .regular))
            if isTurn {
                if side == .computer && game.isThinking {
                    ProgressView().controlSize(.small)
                    Text("Thinking…").font(.footnote).foregroundStyle(.secondary)
                } else if side == .player {
                    Text("Your move").font(.footnote).foregroundStyle(palette.accent)
                }
            }
            Spacer()
            let kings = game.board.kings(side)
            if kings > 0 {
                Label("\(kings)", systemImage: "crown.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("\(game.board.count(side)) left")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var messageBar: some View {
        if let notice = game.notice {
            HStack {
                Label(notice, systemImage: game.hint == nil ? "info.circle.fill" : "lightbulb.fill")
                    .font(.callout)
                    .foregroundStyle(game.hint == nil ? Color.primary : Theme.patternCandidate)
                Spacer()
            }
            .padding(10)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 12)
        }
    }

    private var pausedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "pause.circle.fill").font(.system(size: 54)).foregroundStyle(palette.accent)
            Text("Paused").font(.title2.weight(.semibold))
            Button("Resume") { game.resume() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 4) {
            ControlButton(title: "Undo", systemImage: "arrow.uturn.backward", isOn: false) { game.undo() }
                .disabled(!game.canUndo)
                .opacity(game.canUndo ? 1 : 0.35)
            ControlButton(title: "Hint", systemImage: "lightbulb", isOn: false) { game.requestHint() }
                .disabled(!game.acceptsInput)
                .opacity(game.acceptsInput ? 1 : 0.35)
        }
        .padding(.horizontal, 8)
    }

    private var gameMenu: some View {
        Menu {
            Section("New game") {
                ForEach(CheckersDifficulty.allCases) { d in
                    Button(d.title) { onNewGame(d) }
                }
            }
            Button("Start over", systemImage: "arrow.counterclockwise") { confirmRestart = true }
            Toggle("Show pieces that can move", isOn: $showMovable)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Game menu")
    }

    private func completionCard(_ outcome: CheckersOutcome) -> some View {
        let (icon, color, title): (String, Color, String) = {
            switch outcome {
            case .win(.player): return ("checkmark.seal.fill", Theme.placement, "You won!")
            case .win(.computer): return ("flag.fill", Theme.wrongText, "The computer won")
            case .draw: return ("equal.circle.fill", palette.accent, "It's a draw")
            }
        }()
        return ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundStyle(color)
                Text(title).font(.largeTitle.weight(.bold))
                Text("\(game.difficulty.title) · \(formatTime(game.elapsed)) · \(game.save.moves) moves")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                if case .draw = outcome {
                    Text("Forty moves each went by with no capture and no piece moving forward.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                HStack {
                    if game.canUndo, case .win(.computer) = outcome {
                        Button("Undo") { game.undo() }
                            .buttonStyle(.bordered)
                    } else {
                        Button("Done") { dismiss() }
                            .buttonStyle(.bordered)
                    }
                    Button("New Game") { onNewGame(game.difficulty) }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 6)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(32)
        }
    }
}

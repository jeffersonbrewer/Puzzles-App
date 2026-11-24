import SwiftUI

struct SolitaireGameView: View {
    @Environment(\.palette) private var palette
    @ObservedObject var game: SolitaireGame
    var onNewGame: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmRestart = false

    var body: some View {
        VStack(spacing: 12) {
            statusBar
            ZStack {
                SolitaireBoardView(game: game)
                    .opacity(game.isPaused ? 0 : 1)
                    .allowsHitTesting(game.acceptsInput)
                if game.isPaused { pausedCard }
            }
            if let hint = game.hint { hintBar(hint) }
            controls
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedBackground()
        .navigationTitle("Draw \(game.drawCount)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { gameMenu }
        }
        .overlay {
            if game.isComplete { completionCard }
        }
        .onAppear { game.start() }
        .onDisappear { game.suspend() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.pause() }
        }
        .confirmationDialog("Restart this deal?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Start over", role: .destructive) { game.restart() }
        }
    }

    // MARK: Status bar

    private var statusBar: some View {
        HStack {
            Label("\(game.moves) move\(game.moves == 1 ? "" : "s")", systemImage: "hand.tap")
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
            .disabled(game.isComplete)
            .accessibilityLabel(game.isPaused ? "Resume" : "Pause")
        }
        .padding(.horizontal, 16)
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
            if game.canFinish {
                ControlButton(title: "Finish", systemImage: "wand.and.stars", isOn: true) { game.finish() }
            }
        }
        .padding(.horizontal, 8)
        .disabled(!game.acceptsInput)
    }

    private func hintBar(_ hint: SolitaireHint) -> some View {
        HStack {
            Label(hint.text, systemImage: "lightbulb.fill")
                .font(.callout)
                .foregroundStyle(Theme.patternCandidate)
            Spacer()
            Button {
                game.dismissHint()
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .accessibilityLabel("Close hint")
        }
        .padding(10)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
    }

    private var gameMenu: some View {
        Menu {
            Section("New game") {
                Button("Draw 1") { onNewGame(1) }
                Button("Draw 3") { onNewGame(3) }
            }
            Button("Restart deal", systemImage: "arrow.counterclockwise") { confirmRestart = true }
                .disabled(game.isComplete)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Game menu")
    }

    private var completionCard: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.placement)
                Text("You won!").font(.largeTitle.weight(.bold))
                Text("\(formatTime(game.elapsed)) · \(game.moves) moves")
                    .font(.title3)
                HStack {
                    Button("Done") { dismiss() }
                        .buttonStyle(.bordered)
                    Button("New Game") { onNewGame(game.drawCount) }
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

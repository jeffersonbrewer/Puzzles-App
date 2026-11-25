import SwiftUI

struct MahjongGameView: View {
    @Environment(\.palette) private var palette
    @ObservedObject var game: MahjongGame
    var onNewGame: (MahjongLayout) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmRestart = false

    var body: some View {
        VStack(spacing: 10) {
            statusBar
            ZStack {
                MahjongBoardView(game: game)
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
        .navigationTitle(game.layout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { gameMenu }
        }
        .overlay {
            if game.isComplete {
                completionCard
            } else if game.isStuck && !game.isPaused {
                stuckCard
            }
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(game.board.remaining) tiles left")
                    .font(.subheadline.weight(.semibold))
                Text(openText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    private var openText: String {
        let open = game.openPairCount
        return open == 1 ? "1 match open" : "\(open) matches open"
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
            ControlButton(title: "Shuffle", systemImage: "shuffle", isOn: false) { game.shuffle() }
        }
        .padding(.horizontal, 8)
        .disabled(!game.acceptsInput)
    }

    private func hintBar(_ hint: MahjongHint) -> some View {
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
                ForEach(MahjongLayout.all) { layout in
                    Button("\(layout.name) · \(layout.tileCount) tiles") { onNewGame(layout) }
                }
            }
            Button("Restart deal", systemImage: "arrow.counterclockwise") { confirmRestart = true }
                .disabled(game.isComplete)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Game menu")
    }

    // MARK: End of game

    private var stuckCard: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "rectangle.on.rectangle.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.patternCandidate)
                Text("No more matches").font(.title2.weight(.bold))
                Text("Shuffle the \(game.board.remaining) tiles left, or undo and try another pair.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Undo") { game.undo() }
                        .buttonStyle(.bordered)
                        .disabled(!game.canUndo)
                    Button("Shuffle") { game.shuffle() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 4)
            }
            .padding(26)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(32)
        }
    }

    private var completionCard: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.placement)
                Text("Board cleared!").font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(summary).font(.title3)
                HStack {
                    Button("Done") { dismiss() }
                        .buttonStyle(.bordered)
                    Button("New Game") { onNewGame(game.layout) }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 6)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding(32)
        }
    }

    private var summary: String {
        let shuffles = game.save.shuffles
        let extra = shuffles == 0 ? "" : " · \(shuffles) shuffle\(shuffles == 1 ? "" : "s")"
        return "\(formatTime(game.elapsed))\(extra)"
    }
}

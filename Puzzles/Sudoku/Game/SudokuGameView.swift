import SwiftUI

struct SudokuGameView: View {
    @Environment(\.palette) private var palette
    @ObservedObject var game: SudokuGame
    var onNewGame: (Difficulty) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SudokuSettingsKey.showMistakes) private var showMistakes = true
    @AppStorage(SudokuSettingsKey.highlightPeers) private var highlightPeers = true
    @State private var confirmRestart = false

    var body: some View {
        VStack(spacing: 14) {
            statusBar
            ZStack {
                SudokuBoardView(
                    values: game.values,
                    givens: game.givens,
                    notes: game.notes,
                    selected: game.selected,
                    wrongCells: showMistakes ? game.wrongCells : [],
                    highlightPeers: highlightPeers,
                    step: game.hint?.step,
                    showStepResult: game.hint?.step != nil,
                    onTap: { game.select($0) }
                )
                .opacity(game.isPaused ? 0 : 1)
                if game.isPaused { pausedCard }
            }
            .padding(.horizontal, 8)

            if let hint = game.hint {
                hintCard(hint)
            } else {
                controls
                NumberPadView(game: game)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .navigationTitle(game.difficulty.title)
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
        .confirmationDialog("Restart this puzzle?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Clear my entries", role: .destructive) { game.restart() }
        }
    }

    // MARK: Status bar

    private var statusBar: some View {
        HStack {
            Label(showMistakes ? "\(game.mistakes) mistake\(game.mistakes == 1 ? "" : "s")" : "Mistakes hidden",
                  systemImage: "xmark.circle")
                .font(.subheadline)
                .foregroundStyle(game.mistakes > 0 && showMistakes ? Theme.wrongText : .secondary)
            Spacer()
            // game.clockTick changes every second, which refreshes this view.
            Text(formatTime(game.elapsed))
                .font(.system(.body, design: .rounded).monospacedDigit().weight(.semibold))
            Button {
                game.isPaused ? game.resume() : game.pause()
            } label: {
                Image(systemName: game.isPaused ? "play.fill" : "pause.fill")
                    .frame(width: 32, height: 32)
            }
            .disabled(game.isComplete)
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
            ControlButton(title: "Erase", systemImage: "eraser", isOn: false) { game.erase() }
            ControlButton(title: game.notesMode ? "Notes On" : "Notes", systemImage: "pencil", isOn: game.notesMode) {
                game.notesMode.toggle()
            }
            ControlButton(title: game.autoCandidates ? "Auto On" : "Auto", systemImage: "wand.and.stars", isOn: game.autoCandidates) {
                game.toggleAutoCandidates()
            }
            ControlButton(title: "Hint", systemImage: "lightbulb", isOn: false) { game.requestHint() }
        }
        .padding(.horizontal, 8)
        .disabled(game.isPaused || game.isComplete)
    }

    private func hintCard(_ hint: SudokuHint) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(hint.title, systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(Theme.patternCandidate)
            Text(hint.text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Close") { game.dismissHint() }
                    .buttonStyle(.bordered)
                Spacer()
                if let step = hint.step {
                    Button(step.placements.isEmpty ? "Remove candidates" : "Fill it in") { game.applyHint() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 12)
    }

    private var gameMenu: some View {
        Menu {
            Section("New game") {
                ForEach(Difficulty.allCases) { d in
                    Button(d.title) { onNewGame(d) }
                }
            }
            Button("Restart puzzle", systemImage: "arrow.counterclockwise") { confirmRestart = true }
                .disabled(game.isComplete)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var completionCard: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.placement)
                Text("Solved!").font(.largeTitle.weight(.bold))
                Text("\(game.difficulty.title) in \(formatTime(game.elapsed))")
                    .font(.title3)
                Text(game.mistakes == 0 ? "No mistakes. Nice!" : "\(game.mistakes) mistake\(game.mistakes == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Done") { dismiss() }
                        .buttonStyle(.bordered)
                    Button("New \(game.difficulty.title)") { onNewGame(game.difficulty) }
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

struct ControlButton: View {
    @Environment(\.palette) private var palette
    let title: String
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 44, height: 34)
                    .background(isOn ? palette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(isOn ? palette.accent : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct NumberPadView: View {
    @Environment(\.palette) private var palette
    @ObservedObject var game: SudokuGame

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...9, id: \.self) { d in
                let left = game.remaining(d)
                Button {
                    game.input(d)
                } label: {
                    VStack(spacing: 2) {
                        Text("\(d)")
                            .font(.system(size: game.notesMode ? 24 : 30, weight: game.notesMode ? .regular : .medium, design: .rounded))
                            .foregroundStyle(game.notesMode ? palette.accent : .primary)
                        Text(left > 0 ? "\(left)" : " ")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        if game.notesMode {
                            RoundedRectangle(cornerRadius: 10).strokeBorder(palette.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }
                }
                .buttonStyle(.plain)
                .opacity(left <= 0 && !game.notesMode ? 0.3 : 1)
                .disabled(game.isPaused || game.isComplete)
            }
        }
        .padding(.horizontal, 8)
    }
}

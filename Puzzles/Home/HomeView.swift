import SwiftUI

/// Every game in the app. To add a new game, add a case here and give it a
/// destination view in its own folder (for example Puzzles/Solitaire/).
enum PuzzleGame: String, CaseIterable, Identifiable {
    case sudoku
    case solitaire

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sudoku: return "Sudoku"
        case .solitaire: return "Solitaire"
        }
    }

    var subtitle: String {
        switch self {
        case .sudoku: return "Classic 9x9 with notes, hints and training"
        case .solitaire: return "Coming soon"
        }
    }

    var systemImage: String {
        switch self {
        case .sudoku: return "square.grid.3x3.fill"
        case .solitaire: return "suit.spade.fill"
        }
    }

    var isAvailable: Bool { self == .sudoku }

    @MainActor @ViewBuilder
    var destination: some View {
        switch self {
        case .sudoku: SudokuHomeView()
        case .solitaire: Text("Solitaire is coming soon.")
        }
    }
}

struct HomeView: View {
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(PuzzleGame.allCases) { game in
                        if game.isAvailable {
                            NavigationLink { game.destination } label: { GameCard(game: game) }
                                .buttonStyle(.plain)
                        } else {
                            GameCard(game: game).opacity(0.5)
                        }
                    }
                    Text("No ads. No tracking. Just puzzles.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            .themedBackground()
            .navigationTitle("Puzzles")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                ThemedRoot {
                    NavigationStack {
                        Form {
                            Section("Appearance") {
                                AppearancePicker()
                            }
                            Section {
                                NavigationLink {
                                    ThemeSettingsView()
                                } label: {
                                    ThemeColorRow()
                                }
                                NavigationLink {
                                    AppIconPickerView()
                                } label: {
                                    Text("App Icon")
                                }
                            }
                        }
                        .themedBackground()
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showSettings = false }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct GameCard: View {
    @Environment(\.palette) private var palette
    let game: PuzzleGame

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: game.systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(palette.accent.gradient, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title).font(.title3.weight(.semibold))
                Text(game.subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if game.isAvailable {
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(palette.card, in: RoundedRectangle(cornerRadius: 20))
    }
}

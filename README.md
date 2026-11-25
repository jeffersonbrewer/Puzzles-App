# Puzzles

A personal, ad-free puzzle app for iPhone, built with SwiftUI. It has Sudoku and Solitaire (Klondike, FreeCell and Spider), and is set up so more games can be added alongside them.

## Sudoku features

- **Four difficulties.** Easy and Medium need only singles. Hard needs pointing pairs, naked/hidden pairs or triples. Expert needs X-Wing, Y-Wing, XYZ-Wing or Swordfish. Every puzzle has exactly one solution and can be solved by logic alone.
- **Timer** with pause. It pauses automatically when you leave the app.
- **Notes mode** to switch between entering numbers and pencil-mark candidates.
- **Auto candidates** fills in every possible candidate and keeps them up to date as you play.
- **Matching numbers are highlighted** when you select a cell, including matching notes. The cell's row, column and box are shaded too (can be turned off).
- **Undo**, **Erase** and **Restart**.
- **Real-time mistakes.** A wrong number turns red right away, and mistakes are counted (can be turned off).
- **Hints** that name the technique, highlight the pattern on the board and explain it.
- **Training mode** with lessons for Hidden/Naked Singles, Pointing Pairs, Box/Line Reduction, Naked/Hidden Pairs, Naked Triples, X-Wing, Y-Wing, XYZ-Wing and Swordfish. Each lesson explains the idea, then walks through a real board: find it, see the pattern, see the result, apply it. "Another example" loads a new position.
- Your current game is saved automatically.

## Solitaire features

- **Klondike, draw 1 or draw 3**, with unlimited trips through the stock.
- **FreeCell**: every card face up, four free cells, and runs move together when there is room.
- **Spider** with 1, 2 or 4 suits. Finished king-to-ace runs clear themselves.
- **How to play** lessons for FreeCell and Spider. Each one explains an idea, then gives you a small board to try it on, with Show me if you get stuck.
- **Tap or drag.** Tap a card to send it to its best spot, or drag a card or a run anywhere it fits.
- **Undo**, **Hint** and **Restart deal**.
- **Finish** plays out the rest once every card is face up (Klondike) or every column is in order (FreeCell).
- **Timer** with pause, and a move counter.
- Your current game is saved automatically. Deals are random, so some can't be won.

## Look and feel

- **Dark mode.** Choose System, Light or Dark from the gear on the home screen or in a game's settings.
- **Colors.** Tint the background (Paper, Sand, Sage, Mint, Sky, Lavender, Blush, or any color with the Color and Strength sliders) and choose the accent used for your numbers, highlights and card backs. Both adjust themselves for dark mode.
- **App icon.** Six icons to choose from (Teal, Forest, Midnight, Paper, Sunset, Mono), from the gear on the home screen. Redraw them with `python3 tools/make_icons.py`.

## Run it on your iPhone

You need a Mac with **Xcode 16 or newer** and a free Apple ID. No paid developer account is needed.

1. **Get the code.** In Terminal:
   ```
   git clone https://github.com/jeffersonbrewer/puzzles-app.git
   open puzzles-app/Puzzles.xcodeproj
   ```
2. **Sign in to Xcode.** Xcode > Settings > Accounts, click **+** and add your Apple ID.
3. **Set the team.** In the left sidebar click the blue **Puzzles** project, select the **Puzzles** target, open **Signing & Capabilities**, keep "Automatically manage signing" checked and pick your name **(Personal Team)** under Team. If Xcode says the bundle identifier is taken, change `com.jeffersonbrewer.Puzzles` to anything unique, like `com.yourname.puzzles`.
4. **Connect your iPhone** with a cable and unlock it. Tap **Trust** if asked.
5. **Turn on Developer Mode** on the phone (first time only): Settings > Privacy & Security > Developer Mode, turn it on and let the phone restart.
6. **Pick your iPhone** in the device menu at the top of Xcode and press **Run** (the ▶ button, or Cmd+R).
7. **Trust the developer** on the phone (first time only): Settings > General > VPN & Device Management, tap your Apple ID and tap **Trust**. Then open Puzzles.

With a free Apple ID, apps you install this way expire after **7 days**. When that happens, connect the phone and press Run again; your saved game stays. (A paid Apple Developer account, $99/year, extends this to a year.)

You can also press Run with an iPhone simulator selected to try it on the Mac.

## Project layout

```
Puzzles.xcodeproj         Xcode project (uses synchronized folders, so new files in Puzzles/ are picked up automatically)
Puzzles/
  PuzzlesApp.swift        App entry point
  Home/HomeView.swift     Game picker. Add new games to the PuzzleGame enum here.
  Shared/Theme.swift      Colors and small helpers shared by all games
  Sudoku/
    SudokuHomeView.swift  Continue, new game, training, settings
    Engine/               Grid geometry, brute-force solver, generator, human-style logic solver
    Game/                 Game state (undo, notes, timer, hints) and the board/game screens
    Training/             Lesson text and lesson screens
  Solitaire/
    SolitaireHomeView.swift  Continue, new games, lessons, settings
    Engine/               Cards and the Klondike, FreeCell and Spider rules, hints, finishing (no UI)
    Game/                 Game state (undo, timer, saving), card drawing and the board/game screens
    Lessons/              FreeCell and Spider lesson text, practice boards and screens
  Assets.xcassets         App icon and accent color
tools/                    Python reference of the engine, used to build the training example bank
```

### Adding another game

1. Create a folder such as `Puzzles/Minesweeper/` with its own views and logic.
2. In `Home/HomeView.swift`, add its case to `PuzzleGame` and return its main view from `destination`.

### Regenerating training examples

`Puzzles/Sudoku/Engine/TrainingBank.swift` holds puzzles known to reach each technique. To make new ones, run `python3 tools/make_training_bank.py` from the `tools` folder and copy the output into that file.

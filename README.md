# Puzzles

A personal, ad-free puzzle app for iPhone, built with SwiftUI. Sudoku is the first game; the app is set up so more games (Solitaire is next) can be added alongside it.

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
  Assets.xcassets         App icon and accent color
tools/                    Python reference of the engine, used to build the training example bank
```

### Adding another game

1. Create a folder such as `Puzzles/Solitaire/` with its own views and logic.
2. In `Home/HomeView.swift`, add or enable its case in `PuzzleGame` and return its main view from `destination`.

### Regenerating training examples

`Puzzles/Sudoku/Engine/TrainingBank.swift` holds puzzles known to reach each technique. To make new ones, run `python3 tools/make_training_bank.py` from the `tools` folder and copy the output into that file.

import Foundation

/// One row from a lesson: a clue, what's already marked, and why the
/// squares that follow from it are forced.
struct NonogramLineExample {
    let clue: [Int]
    /// "." blank, "#" filled, "x" crossed out.
    let start: String
    let explanation: String

    var cells: [NonoCell] {
        start.map { $0 == "#" ? .filled : ($0 == "x" ? .crossed : .unknown) }
    }

    /// What the clue forces, worked out by the same solver the hints use.
    var solved: [NonoCell] {
        LineSolver.solve(clues: clue, line: cells) ?? cells
    }
}

struct NonogramLesson: Identifiable {
    let id: String
    let title: String
    let summary: String
    let lookFor: [String]
    let whyItWorks: String
    let prompt: String
    let examples: [NonogramLineExample]

    static let basics: [NonogramLesson] = [howToPlay, addsUp, overlap]
    static let more: [NonogramLesson] = [edges, reach, finished, smallGaps]

    static let howToPlay = NonogramLesson(
        id: "howToPlay",
        title: "How to Play",
        summary: "Each puzzle hides a picture. The numbers beside each row and above each column tell you the runs of filled squares in that line, in order, with at least one empty square between runs.",
        lookFor: [
            "Read a clue like \"3 1\" as: a run of 3 filled squares, then later a single filled square.",
            "Fill a square when you know it's part of the picture. Switch to Cross to mark squares you know are empty.",
            "Every row and column can be worked out from its clue and the squares already marked. You never need to guess.",
            "A clue turns grey when its line matches it."
        ],
        whyItWorks: "Each line is a small puzzle of its own. Whatever you work out in a row gives new squares to the columns that cross it, and the other way round.",
        prompt: "Which squares in this row must be filled, and which must be empty?",
        examples: [
            NonogramLineExample(clue: [5], start: ".....", explanation: "A run of 5 in a row of 5 squares takes the whole row."),
            NonogramLineExample(clue: [], start: ".....", explanation: "A 0 means the row is empty. Cross out every square."),
            NonogramLineExample(clue: [1, 3], start: ".....", explanation: "1, a gap, then 3 adds up to exactly 5, so there's only one way to place them.")
        ]
    )

    static let addsUp = NonogramLesson(
        id: "addsUp",
        title: "Lines That Add Up",
        summary: "Add up the clue's numbers plus one gap between each pair. If the total equals the line's length, the line has only one answer.",
        lookFor: [
            "Add the numbers in the clue.",
            "Add one for each gap between runs (one less than the number of runs).",
            "If that equals the line's length, fill the runs in order with single gaps."
        ],
        whyItWorks: "The runs need at least that much room. When they need all of it, there's no room to slide anything.",
        prompt: "Do the runs and their gaps fill the whole line?",
        examples: [
            NonogramLineExample(clue: [3, 1], start: ".....", explanation: "3 + 1 + 1 gap = 5, the full length."),
            NonogramLineExample(clue: [1, 1, 1], start: ".....", explanation: "1 + 1 + 1 + 2 gaps = 5, so it alternates filled and empty."),
            NonogramLineExample(clue: [2, 3, 3], start: "..........", explanation: "2 + 3 + 3 + 2 gaps = 10, the full length."),
            NonogramLineExample(clue: [6, 3], start: "..........", explanation: "6 + 3 + 1 gap = 10, the full length.")
        ]
    )

    static let overlap = NonogramLesson(
        id: "overlap",
        title: "Overlap",
        summary: "When a run is longer than half the space it can move in, part of it is filled wherever it goes.",
        lookFor: [
            "Push every run as far left as it will go, and note where each one sits.",
            "Then push them all as far right as they will go.",
            "Squares covered by the same run both times must be filled."
        ],
        whyItWorks: "Every possible position of the run lies between those two extremes, and all of them cover the overlap.",
        prompt: "Slide the runs to each end. Which squares are covered both times?",
        examples: [
            NonogramLineExample(clue: [4], start: ".....", explanation: "Pushed left the 4 covers squares 1-4, pushed right 2-5. Squares 2-4 are covered either way."),
            NonogramLineExample(clue: [7], start: "..........", explanation: "Pushed left the 7 covers 1-7, pushed right 4-10. Squares 4-7 are filled either way."),
            NonogramLineExample(clue: [3, 4], start: "..........", explanation: "The runs and their gap need 8 of 10 squares, so each can move 2. The 3 always covers square 3, and the 4 always covers squares 7-8."),
            NonogramLineExample(clue: [2, 5], start: "..........", explanation: "Each run can move 2 squares. The 2 has no overlap, but the 5 always covers squares 6-8.")
        ]
    )

    static let edges = NonogramLesson(
        id: "edges",
        title: "Starting From an Edge",
        summary: "A filled square near the edge of a line pins down the first run, because that run can't start before the edge.",
        lookFor: [
            "Find a filled square close to the start (or end) of a line.",
            "It must belong to the first (or last) run.",
            "Work out every position that run could take while covering the square. Fill what they share and cross out what none of them reach."
        ],
        whyItWorks: "The edge stops the run from sliding further, so it has only a few places it can be.",
        prompt: "The first run has to cover the filled square. Where can it go?",
        examples: [
            NonogramLineExample(clue: [3], start: "#.........", explanation: "The 3 starts on the first square, so it fills squares 1-3. Nothing else is filled."),
            NonogramLineExample(clue: [4, 2], start: ".#........", explanation: "The 4 covers square 2, so it starts at square 1 or 2. Either way squares 2-4 are filled."),
            NonogramLineExample(clue: [2], start: "x#........", explanation: "Square 1 is empty, so the 2 must start on square 2. Everything else is empty.")
        ]
    )

    static let reach = NonogramLesson(
        id: "reach",
        title: "How Far a Run Reaches",
        summary: "Once you know a square belongs to a run, that run can only stretch so far from it. Squares out of its reach are empty.",
        lookFor: [
            "Find a filled square and decide which run it belongs to.",
            "That run can reach at most its length minus one squares to either side.",
            "Cross out squares no run can reach, and fill any gap between filled squares of the same run."
        ],
        whyItWorks: "A run is one solid block. It can't cover a filled square and also a square too far away from it.",
        prompt: "How far can the run reach from the filled squares?",
        examples: [
            NonogramLineExample(clue: [2], start: "....#.....", explanation: "The 2 covers square 5, so it covers 4-5 or 5-6. Everything else is empty."),
            NonogramLineExample(clue: [3], start: "...#.#....", explanation: "There's only one run, so squares 4 and 6 are in the same 3. It must be 4-6."),
            NonogramLineExample(clue: [4], start: "..#.......", explanation: "The 4 covers square 3, so it must start between squares 1 and 3. It always covers 3-4 and never reaches past square 6.")
        ]
    )

    static let finished = NonogramLesson(
        id: "finished",
        title: "Finished Lines",
        summary: "When every run in a clue is already in place, the rest of the line is empty. Cross it out so the crossing lines can use it.",
        lookFor: [
            "Compare the filled runs in a line with its clue.",
            "If they match, cross out every other square in the line.",
            "Its clue turns grey when the line matches."
        ],
        whyItWorks: "The clue lists every filled square in the line. Once they're all accounted for, no more can be filled.",
        prompt: "Are all the runs already there?",
        examples: [
            NonogramLineExample(clue: [2, 1], start: ".##....#..", explanation: "The 2 and the 1 are both in place, so cross out the rest."),
            NonogramLineExample(clue: [3], start: "...###....", explanation: "The 3 is complete. Every other square is empty."),
            NonogramLineExample(clue: [1, 1], start: "#......#..", explanation: "Two separate squares are filled and the clue has two 1s. The rest is empty.")
        ]
    )

    static let smallGaps = NonogramLesson(
        id: "smallGaps",
        title: "Gaps Too Small",
        summary: "Crossed-out squares split a line into gaps. A gap too short for any run that could go there must be empty.",
        lookFor: [
            "Look at the gaps between crossed-out squares and the ends of the line.",
            "If a gap is shorter than every run that could go in it, cross it out.",
            "Then look again at the space that's left: the runs often overlap there."
        ],
        whyItWorks: "A run can't be split by a crossed-out square, so it needs a gap at least as long as itself.",
        prompt: "Which gaps are too short for the runs?",
        examples: [
            NonogramLineExample(clue: [3], start: "..x.x.....", explanation: "The gaps of 2 and 1 can't hold a 3. That leaves 5 squares for the 3, which always covers square 8."),
            NonogramLineExample(clue: [4], start: "...x......", explanation: "The first gap is only 3 long. The 4 goes in the last 6 squares and always covers 7-8."),
            NonogramLineExample(clue: [2, 2], start: "x.x.x.....", explanation: "The gaps of 1 can't hold a 2. Both runs fit the last 5 squares in only one way.")
        ]
    )
}

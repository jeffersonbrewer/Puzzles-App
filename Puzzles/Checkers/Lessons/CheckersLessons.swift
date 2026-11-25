import Foundation

/// A position to try a lesson's idea on. Diagrams are drawn from your side:
/// top row first, r / R = your man / king, b / B = the computer's man / king.
/// Squares are named like a chessboard: files a-h from the left, ranks 1-8 from your side.
///
/// `tools/checkers_reference.py` checks every diagram and solution in this file.
struct CheckersExercise {
    enum Goal {
        /// Any legal move is fine.
        case anyMove
        /// One of these moves.
        case oneOf([String])
        /// Your move, the computer's forced reply, your move, and so on.
        case line([String])
        /// Any move that leaves the computer nothing to jump.
        case safeMove
        /// Any move that leaves the computer with no move at all (these are examples to show).
        case winningMove([String])
    }

    let prompt: String
    let diagram: [String]
    let goal: Goal
    /// Shown once it's solved.
    let success: String
    /// Shown after a legal move that isn't the answer.
    let tip: String

    var board: Checkers { Checkers(diagram: diagram) }
}

struct CheckersLesson: Identifiable {
    let id: String
    let title: String
    let summary: String
    let lookFor: [String]
    let whyItWorks: String
    let exercises: [CheckersExercise]
}

struct CheckersLessonGroup: Identifiable {
    let title: String
    let lessons: [CheckersLesson]
    var id: String { title }
}

enum CheckersLessons {
    static let groups: [CheckersLessonGroup] = [
        CheckersLessonGroup(title: "Basics", lessons: [moving, capturing, multiJumps, kings, winning]),
        CheckersLessonGroup(title: "Tactics", lessons: [safeMoves, twoForOne]),
    ]

    static let moving = CheckersLesson(
        id: "moving",
        title: "How pieces move",
        summary: "Checkers is played on the dark squares only. Your pieces start at the bottom and move one square diagonally forward, onto an empty dark square.",
        lookFor: [
            "Tap one of your pieces. The dots show where it can go.",
            "Tap a dot to move there.",
            "Pieces never move backward until they become kings."
        ],
        whyItWorks: "Each player has 12 pieces, called men. You and the computer take turns, one move each. In this app you play red from the bottom of the board.",
        exercises: [
            CheckersExercise(
                prompt: "Move any of your pieces one square forward.",
                diagram: [
                    ".....b..",
                    "........",
                    "...b....",
                    "........",
                    "........",
                    "..r.r...",
                    "........",
                    "........",
                ],
                goal: .anyMove,
                success: "That's a move. Every turn you move one piece, diagonally forward onto an empty dark square.",
                tip: "Move one square diagonally forward."
            ),
        ]
    )

    static let capturing = CheckersLesson(
        id: "capturing",
        title: "Capturing",
        summary: "When an opponent's piece is diagonally next to yours and the square right behind it is empty, you can jump over it and take it off the board.",
        lookFor: [
            "Find a computer piece touching one of yours on a diagonal.",
            "Check that the square just past it is empty.",
            "If any jump is possible, you must take it. Other moves aren't allowed that turn."
        ],
        whyItWorks: "Jumps are required. That is the most important rule in checkers: it lets you force your opponent into captures you planned, and it means you must always check what you are offering.",
        exercises: [
            CheckersExercise(
                prompt: "Capture the computer's piece. Try tapping the other piece first to see what happens.",
                diagram: [
                    ".b......",
                    "........",
                    "........",
                    "........",
                    "...b....",
                    "..r...r.",
                    "........",
                    "........",
                ],
                goal: .oneOf(["c3xe5"]),
                success: "Captured. Because a jump was available, it was the only legal move.",
                tip: "Jump over the piece diagonally next to yours."
            ),
            CheckersExercise(
                prompt: "Two jumps are possible. When there's a choice, you may pick either one.",
                diagram: [
                    ".......b",
                    "........",
                    "........",
                    "........",
                    "...b.b..",
                    "....r...",
                    "........",
                    "........",
                ],
                goal: .oneOf(["e3xc5", "e3xg5"]),
                success: "Captured. You must jump, but you can choose which jump to make.",
                tip: "Jump over either piece."
            ),
        ]
    )

    static let multiJumps = CheckersLesson(
        id: "multi-jumps",
        title: "Multiple jumps",
        summary: "After a jump, if the same piece can jump again from where it landed, it keeps going in the same turn.",
        lookFor: [
            "Make the first jump.",
            "From the landing square, look for another piece to jump.",
            "Keep tapping landing squares until no jumps are left."
        ],
        whyItWorks: "A turn isn't over while the jumping piece can still capture. The direction can change between jumps, as long as a man is still moving forward.",
        exercises: [
            CheckersExercise(
                prompt: "Take two pieces in one turn.",
                diagram: [
                    ".......b",
                    "........",
                    "...b....",
                    "........",
                    ".b......",
                    "r.......",
                    "........",
                    "......r.",
                ],
                goal: .oneOf(["a3xc5xe7"]),
                success: "A double jump. Two pieces gone in one move.",
                tip: "Start with the jump on the left side."
            ),
            CheckersExercise(
                prompt: "This time there are three to take.",
                diagram: [
                    ".......b",
                    "........",
                    "...b....",
                    "........",
                    "...b....",
                    "........",
                    "...b....",
                    "..r.....",
                ],
                goal: .oneOf(["c1xe3xc5xe7"]),
                success: "A triple jump. The piece zig-zagged up the board.",
                tip: "Keep jumping with the same piece."
            ),
        ]
    )

    static let kings = CheckersLesson(
        id: "kings",
        title: "Kings",
        summary: "A man that reaches the far row is crowned and becomes a king. Kings move and jump diagonally both forward and backward.",
        lookFor: [
            "Push a man to the top row to crown it.",
            "A king is marked with a crown.",
            "Use a king's backward moves to catch pieces behind it."
        ],
        whyItWorks: "A king can go anywhere on the dark squares, so it's worth about one and a half men. Reaching the last row ends the turn, even in the middle of a jump.",
        exercises: [
            CheckersExercise(
                prompt: "Crown your piece by moving it to the top row.",
                diagram: [
                    "........",
                    "..r.....",
                    ".......b",
                    "........",
                    "........",
                    "........",
                    "........",
                    "......r.",
                ],
                goal: .oneOf(["c7-b8", "c7-d8"]),
                success: "Crowned. Your king can now move backward too.",
                tip: "Move the piece near the top onto the last row."
            ),
            CheckersExercise(
                prompt: "Your king can jump backward. Capture the piece behind it.",
                diagram: [
                    ".....b..",
                    "........",
                    "........",
                    "....R...",
                    "...b....",
                    "........",
                    "........",
                    "r.......",
                ],
                goal: .oneOf(["e5xc3"]),
                success: "A backward jump, something only a king can do.",
                tip: "Jump down and to the left with the king."
            ),
        ]
    )

    static let winning = CheckersLesson(
        id: "winning",
        title: "How to win",
        summary: "You win when the computer can't move on its turn: either it has no pieces left, or every piece it has is blocked.",
        lookFor: [
            "Capture pieces until none are left, or",
            "Move so that each of its pieces has no empty square to go to and nothing to jump.",
            "If 40 moves each go by with only kings moving and nothing captured, the game is a draw."
        ],
        whyItWorks: "A player who can't make a legal move loses. Blocking can win even when you have fewer pieces.",
        exercises: [
            CheckersExercise(
                prompt: "Take the computer's last piece.",
                diagram: [
                    "........",
                    "........",
                    "........",
                    "........",
                    ".....B..",
                    "....r...",
                    "........",
                    "..r.....",
                ],
                goal: .winningMove(["e3xg5"]),
                success: "No pieces left, so you win.",
                tip: "Jump the king."
            ),
            CheckersExercise(
                prompt: "Win by leaving the computer's piece with nowhere to go. Make sure it can't jump you.",
                diagram: [
                    "........",
                    "........",
                    "........",
                    "b.......",
                    "........",
                    "r.r.....",
                    "........",
                    "........",
                ],
                goal: .winningMove(["a3-b4"]),
                success: "Blocked. It can't step onto b4, and c3 behind it is covered, so it can't jump either.",
                tip: "That leaves the computer a move. Block its only square and keep the square behind covered."
            ),
        ]
    )

    static let safeMoves = CheckersLesson(
        id: "safe-moves",
        title: "Safe moves",
        summary: "Before you move, check what the computer could jump afterwards. A piece with an empty square behind it can be taken.",
        lookFor: [
            "Picture the board after your move.",
            "For each of your pieces touching a computer piece, look at the square behind yours.",
            "If that square is empty, your piece can be jumped. Keep pieces backed up by others."
        ],
        whyItWorks: "Moving a piece can uncover a square behind another one. Pieces that move forward together, side by side or backed up from behind, protect each other.",
        exercises: [
            CheckersExercise(
                prompt: "Find a move that doesn't let the computer jump anything.",
                diagram: [
                    "...b....",
                    "........",
                    ".....b.b",
                    "..b.....",
                    "........",
                    "r.r.r.r.",
                    ".r...r..",
                    "........",
                ],
                goal: .safeMove,
                success: "Safe. The computer has nothing to jump after that move.",
                tip: "The computer could jump that piece, because the square behind it is now empty."
            ),
        ]
    )

    static let twoForOne = CheckersLesson(
        id: "two-for-one",
        title: "Two for one",
        summary: "Since jumps are required, you can give the computer a piece on purpose, forcing its piece to land where you can jump two in return.",
        lookFor: [
            "Look for a move that offers a piece.",
            "Work out where the computer's piece will land after its forced jump.",
            "Check whether you can then jump it and another piece in one go."
        ],
        whyItWorks: "The computer has no choice but to jump, so you control where its piece ends up. A good shot wins material even though you give something first.",
        exercises: [
            CheckersExercise(
                prompt: "Offer a piece so you can take two back.",
                diagram: [
                    ".b......",
                    "........",
                    "........",
                    "..b.b...",
                    "........",
                    "..r.r...",
                    ".....r..",
                    "......r.",
                ],
                goal: .line(["e3-d4", "c5xe3", "f2xd4xf6"]),
                success: "Two for one. You gave one piece and took two.",
                tip: "That doesn't set up a double jump. Look for a piece you can give away that the computer must take."
            ),
        ]
    )
}

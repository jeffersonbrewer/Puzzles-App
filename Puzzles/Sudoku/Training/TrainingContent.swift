import Foundation

/// Written lesson text for each technique.
struct TrainingLesson {
    let technique: Technique
    let summary: String
    let lookFor: [String]
    let whyItWorks: String
    /// Shown under the board before the pattern is revealed.
    let prompt: String

    static func lesson(for t: Technique) -> TrainingLesson {
        switch t {
        case .hiddenSingle:
            return TrainingLesson(
                technique: t,
                summary: "A digit that has only one possible home in a row, column or box must go there, even if that cell has other candidates too.",
                lookFor: [
                    "Pick a box (or row, or column) and a digit it is missing.",
                    "Cross out every cell that is filled or that sees that digit elsewhere.",
                    "If only one cell is left, the digit goes there."
                ],
                whyItWorks: "Every house needs each digit exactly once. If there is only one place left for a digit, there is no other choice.",
                prompt: "Find a box, row or column where some digit fits in only one cell."
            )
        case .nakedSingle:
            return TrainingLesson(
                technique: t,
                summary: "A cell with only one candidate left must be that digit.",
                lookFor: [
                    "Look at an empty cell's row, column and box together.",
                    "If eight different digits already appear among them, the ninth is the answer."
                ],
                whyItWorks: "A cell can't repeat a digit that its row, column or box already has. When eight are ruled out, only one is possible.",
                prompt: "Find a cell that has just one candidate."
            )
        case .pointing:
            return TrainingLesson(
                technique: t,
                summary: "When all of a box's candidates for a digit sit in one row (or column), that digit must be in that part of the line. You can remove it from the rest of that row or column.",
                lookFor: [
                    "Choose a box and a digit.",
                    "Check whether every candidate for that digit in the box lines up in a single row or column.",
                    "If so, remove the digit from that line outside the box."
                ],
                whyItWorks: "The box needs the digit somewhere, and every option is on that line. So the line's copy of the digit is inside the box, and no other cell on the line can have it.",
                prompt: "Find a box where one digit's candidates all line up in a row or column."
            )
        case .boxLine:
            return TrainingLesson(
                technique: t,
                summary: "The reverse of a pointing pair. When all of a row's (or column's) candidates for a digit are inside one box, the digit can be removed from the rest of that box.",
                lookFor: [
                    "Choose a row or column and a digit.",
                    "Check whether every candidate for that digit falls inside the same box.",
                    "If so, remove the digit from the other cells of that box."
                ],
                whyItWorks: "The line must place the digit in one of those cells, all of which belong to the box. That uses up the box's copy of the digit.",
                prompt: "Find a row or column where one digit's candidates all sit in a single box."
            )
        case .nakedPair:
            return TrainingLesson(
                technique: t,
                summary: "Two cells in the same house with exactly the same two candidates must hold those two digits between them. Remove both digits from the rest of the house.",
                lookFor: [
                    "Look for two cells with matching two-candidate notes, like {3,7} and {3,7}.",
                    "They must share a row, column or box.",
                    "Remove those two digits from every other cell in that house."
                ],
                whyItWorks: "One cell gets the first digit and the other gets the second. We don't know which way round, but either way both digits are used up in that house.",
                prompt: "Find two cells in the same house with the same two candidates."
            )
        case .hiddenPair:
            return TrainingLesson(
                technique: t,
                summary: "If two digits can only go in the same two cells of a house, those cells must be those two digits. Any other candidates in those cells can be removed.",
                lookFor: [
                    "In a house, count where each missing digit can go.",
                    "Find two digits that each have exactly two spots, and the spots are the same two cells.",
                    "Clear every other candidate from those two cells."
                ],
                whyItWorks: "Both digits must appear in the house, and those two cells are the only options for either. So the cells are fully claimed by that pair.",
                prompt: "Find two digits that share the same two possible cells in a house."
            )
        case .nakedTriple:
            return TrainingLesson(
                technique: t,
                summary: "Three cells in a house whose candidates use only three digits in total must hold those three digits. Remove them from the rest of the house.",
                lookFor: [
                    "Look for three cells in one house with small candidate sets.",
                    "Combine their candidates. If only three different digits appear, it's a triple.",
                    "Each cell doesn't need all three, for example {1,4}, {4,8} and {1,8} works."
                ],
                whyItWorks: "Three cells, three digits: every digit in the set must land in one of those cells, so none can appear elsewhere in the house.",
                prompt: "Find three cells in one house that share just three candidates between them."
            )
        case .xWing:
            return TrainingLesson(
                technique: t,
                summary: "If a digit has exactly two spots in each of two rows, and those spots are in the same two columns, the four cells form a rectangle. The digit can be removed from the rest of both columns. It also works with rows and columns swapped.",
                lookFor: [
                    "Pick a digit and find rows where it has only two candidates.",
                    "Look for two such rows whose candidates line up in the same two columns.",
                    "Remove the digit from every other cell in those two columns."
                ],
                whyItWorks: "Each row's digit goes in one of its two spots. If the top row takes the left corner, the bottom row must take the right corner, and the reverse. Either way both columns get their copy of the digit from this rectangle.",
                prompt: "Pick a digit and look for two rows (or columns) where it appears in exactly the same two places."
            )
        case .yWing:
            return TrainingLesson(
                technique: t,
                summary: "Three two-candidate cells: a pivot {A,B} that sees two wings {A,C} and {B,C}. Whatever the pivot is, one wing becomes C. Any cell that sees both wings can't be C.",
                lookFor: [
                    "Find a cell with two candidates. This is the pivot, for example {2,5}.",
                    "Find a cell it sees that shares one digit with it plus a new one, like {2,9}.",
                    "Find another cell the pivot sees with the other pivot digit and the same new one, like {5,9}.",
                    "Remove the shared digit (9 here) from cells that see both wings."
                ],
                whyItWorks: "If the pivot is A, the A-wing must be C. If the pivot is B, the B-wing must be C. One of them is C no matter what, so a cell seeing both can never be C.",
                prompt: "Find a two-candidate pivot cell that sees two other two-candidate cells sharing one digit."
            )
        case .xyzWing:
            return TrainingLesson(
                technique: t,
                summary: "Like a Y-Wing, but the pivot has three candidates {A,B,C}. With wings {A,C} and {B,C}, one of the three cells must be C, so cells that see all three can't be C.",
                lookFor: [
                    "Find a cell with three candidates. This is the pivot.",
                    "Find two cells it sees, each with two of the pivot's digits and sharing one digit.",
                    "Remove that shared digit from cells that see the pivot and both wings."
                ],
                whyItWorks: "The pivot is A, B or C. If it's C, the pivot itself is C. If it's A or B, one wing is forced to C. So C is always in one of the three, and anything seeing all three loses C.",
                prompt: "Find a three-candidate cell that sees two two-candidate cells made from its digits."
            )
        case .swordfish:
            return TrainingLesson(
                technique: t,
                summary: "An X-Wing stretched to three rows and three columns. If a digit's candidates in three rows all fall within the same three columns, remove it from the rest of those columns.",
                lookFor: [
                    "Pick a digit and find rows where it has two or three candidates.",
                    "Look for three such rows whose candidates together use only three columns.",
                    "Remove the digit from every other cell in those three columns."
                ],
                whyItWorks: "The three rows need three copies of the digit, all in different columns, and only three columns are available. So those columns are filled by these rows.",
                prompt: "Pick a digit and look for three rows whose candidates stay inside the same three columns."
            )
        }
    }
}

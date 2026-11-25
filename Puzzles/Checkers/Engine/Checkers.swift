import Foundation

/// Checkers (American rules, 8x8) with no UI.
///
/// Squares are numbered 0...63, row by row from the top-left. Row 0 is the
/// computer's back row and row 7 is the player's. Only dark squares, where
/// row + column is odd, are used.
enum CheckersSide: String, Codable {
    case player, computer

    var opponent: CheckersSide { self == .player ? .computer : .player }

    /// The row direction a man moves in.
    var forward: Int { self == .player ? -1 : 1 }

    /// A man that reaches this row is crowned.
    var crownRow: Int { self == .player ? 0 : 7 }

    /// The side's own back row.
    var homeRow: Int { self == .player ? 7 : 0 }
}

struct CheckersPiece: Codable, Hashable, Identifiable {
    /// Stable across moves, so the board can animate a piece as it travels.
    var id: Int
    var side: CheckersSide
    var isKing = false
}

struct CheckersMove: Codable, Hashable {
    /// The squares the piece visits: start, any jump landings, and the end.
    var path: [Int]
    /// Squares of captured pieces, in jump order.
    var captures: [Int] = []

    var from: Int { path[0] }
    var to: Int { path[path.count - 1] }
    var isCapture: Bool { !captures.isEmpty }

    /// Written like "c3-d4", or "a3xc5xe7" for jumps.
    var notation: String {
        path.map(Checkers.name).joined(separator: isCapture ? "x" : "-")
    }
}

enum CheckersOutcome: Equatable, Codable {
    case win(CheckersSide)
    case draw
}

struct Checkers: Codable, Equatable {
    var squares: [CheckersPiece?]
    var turn: CheckersSide
    /// Moves in a row by either side with no capture and no man moving.
    var quietPlies = 0

    /// 40 moves each with only kings shuffling is a draw.
    static let drawPlies = 80

    // MARK: - Geometry

    static func row(_ s: Int) -> Int { s / 8 }
    static func column(_ s: Int) -> Int { s % 8 }
    static func isDark(_ s: Int) -> Bool { (row(s) + column(s)) % 2 == 1 }

    static func square(_ row: Int, _ column: Int) -> Int? {
        guard (0..<8).contains(row), (0..<8).contains(column) else { return nil }
        return row * 8 + column
    }

    /// Board name like "c3": files a-h from the left, ranks 1-8 from the player's side.
    static func name(_ s: Int) -> String {
        let file = Character(UnicodeScalar(UInt8(97 + column(s))))
        return "\(file)\(8 - row(s))"
    }

    static func square(named name: String) -> Int? {
        let chars = Array(name.lowercased())
        guard chars.count == 2,
              let f = chars[0].asciiValue, (97...104).contains(f),
              let rank = Int(String(chars[1])), (1...8).contains(rank) else { return nil }
        return square(8 - rank, Int(f) - 97)
    }

    // MARK: - Setting up

    static func start(firstMove: CheckersSide) -> Checkers {
        var squares = [CheckersPiece?](repeating: nil, count: 64)
        var id = 0
        for s in 0..<64 where isDark(s) {
            if row(s) <= 2 {
                squares[s] = CheckersPiece(id: id, side: .computer)
                id += 1
            } else if row(s) >= 5 {
                squares[s] = CheckersPiece(id: id, side: .player)
                id += 1
            }
        }
        return Checkers(squares: squares, turn: firstMove)
    }

    // MARK: - Reading the board

    func count(_ side: CheckersSide) -> Int {
        squares.reduce(0) { $0 + ($1?.side == side ? 1 : 0) }
    }

    func kings(_ side: CheckersSide) -> Int {
        squares.reduce(0) { $0 + ($1?.side == side && $1?.isKing == true ? 1 : 0) }
    }

    private static let kingDirections = [(-1, -1), (-1, 1), (1, -1), (1, 1)]

    private static func directions(for piece: CheckersPiece) -> [(Int, Int)] {
        if piece.isKing { return kingDirections }
        let f = piece.side.forward
        return [(f, -1), (f, 1)]
    }

    // MARK: - Moves

    /// Every legal move for the side to move. If any capture exists, only
    /// captures are legal, and a jumping piece must keep jumping while it can.
    func legalMoves() -> [CheckersMove] {
        legalMoves(for: turn)
    }

    func legalMoves(for side: CheckersSide) -> [CheckersMove] {
        var jumps: [CheckersMove] = []
        for s in 0..<64 {
            guard let piece = squares[s], piece.side == side else { continue }
            addJumps(at: s, piece: piece, origin: s, path: [s], captured: [], into: &jumps)
        }
        if !jumps.isEmpty { return jumps }

        var moves: [CheckersMove] = []
        for s in 0..<64 {
            guard let piece = squares[s], piece.side == side else { continue }
            for (dr, dc) in Self.directions(for: piece) {
                if let t = Self.square(Self.row(s) + dr, Self.column(s) + dc), squares[t] == nil {
                    moves.append(CheckersMove(path: [s, t]))
                }
            }
        }
        return moves
    }

    /// True if `side` has a capture available right now.
    func hasCapture(for side: CheckersSide) -> Bool {
        legalMoves(for: side).first?.isCapture ?? false
    }

    private func addJumps(at s: Int, piece: CheckersPiece, origin: Int, path: [Int], captured: [Int], into result: inout [CheckersMove]) {
        var extended = false
        let r = Self.row(s), c = Self.column(s)
        for (dr, dc) in Self.directions(for: piece) {
            guard let over = Self.square(r + dr, c + dc),
                  let land = Self.square(r + 2 * dr, c + 2 * dc),
                  let victim = squares[over], victim.side != piece.side,
                  !captured.contains(over),
                  squares[land] == nil || land == origin else { continue }
            extended = true
            let nextPath = path + [land]
            let nextCaptured = captured + [over]
            if !piece.isKing && Self.row(land) == piece.side.crownRow {
                // Being crowned ends the move.
                result.append(CheckersMove(path: nextPath, captures: nextCaptured))
            } else {
                addJumps(at: land, piece: piece, origin: origin, path: nextPath, captured: nextCaptured, into: &result)
            }
        }
        if !extended && path.count > 1 {
            result.append(CheckersMove(path: path, captures: captured))
        }
    }

    mutating func apply(_ move: CheckersMove) {
        guard var piece = squares[move.from] else { return }
        let wasMan = !piece.isKing
        squares[move.from] = nil
        for c in move.captures { squares[c] = nil }
        if wasMan && Self.row(move.to) == piece.side.crownRow { piece.isKing = true }
        squares[move.to] = piece
        quietPlies = (move.isCapture || wasMan) ? 0 : quietPlies + 1
        turn = turn.opponent
    }

    func applying(_ move: CheckersMove) -> Checkers {
        var next = self
        next.apply(move)
        return next
    }

    /// Boards to show one hop at a time while a multi-jump plays out.
    /// The last one is the finished move.
    func animationSteps(_ move: CheckersMove) -> [Checkers] {
        guard move.captures.count > 1, let piece = squares[move.from] else { return [applying(move)] }
        var steps: [Checkers] = []
        var board = self
        for i in 1..<(move.path.count - 1) {
            board.squares[move.path[i - 1]] = nil
            board.squares[move.captures[i - 1]] = nil
            board.squares[move.path[i]] = piece
            steps.append(board)
        }
        steps.append(applying(move))
        return steps
    }

    /// Finds the legal move written as "c3-d4" or "a3xc5xe7".
    func move(_ notation: String) -> CheckersMove? {
        legalMoves().first { $0.notation == notation.lowercased() }
    }

    // MARK: - Result

    /// Nil while the game is still going.
    var outcome: CheckersOutcome? {
        if legalMoves().isEmpty { return .win(turn.opponent) }
        if quietPlies >= Self.drawPlies { return .draw }
        return nil
    }
}

extension Checkers {
    /// Builds a position from 8 strings of 8 characters, top row first:
    /// r / R = player man / king, b / B = computer man / king, anything else empty.
    init(diagram: [String], turn: CheckersSide = .player) {
        var squares = [CheckersPiece?](repeating: nil, count: 64)
        var id = 0
        for (r, line) in diagram.prefix(8).enumerated() {
            for (c, ch) in line.prefix(8).enumerated() {
                let side: CheckersSide
                switch ch {
                case "r", "R": side = .player
                case "b", "B": side = .computer
                default: continue
                }
                squares[r * 8 + c] = CheckersPiece(id: id, side: side, isKing: ch.isUppercase)
                id += 1
            }
        }
        self.init(squares: squares, turn: turn)
    }
}

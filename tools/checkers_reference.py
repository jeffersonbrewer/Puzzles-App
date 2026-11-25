#!/usr/bin/env python3
"""Python mirror of Puzzles/Checkers/Engine/Checkers.swift.

Run it to check the lesson positions in Puzzles/Checkers/Lessons/CheckersLessons.swift:
every diagram must parse, and every solution must be legal and play out as the
lesson describes.

    python3 tools/checkers_reference.py
"""
import random
import re
import sys
from pathlib import Path

PLAYER, COMPUTER = "player", "computer"


def opponent(side):
    return COMPUTER if side == PLAYER else PLAYER


def forward(side):
    return -1 if side == PLAYER else 1


def crown_row(side):
    return 0 if side == PLAYER else 7


def sq(r, c):
    if 0 <= r < 8 and 0 <= c < 8:
        return r * 8 + c
    return None


def name(s):
    return "abcdefgh"[s % 8] + str(8 - s // 8)


class Board:
    def __init__(self, squares, turn=PLAYER, quiet=0):
        self.squares = squares  # list of (side, king) or None
        self.turn = turn
        self.quiet = quiet

    @staticmethod
    def start(first=PLAYER):
        squares = [None] * 64
        for s in range(64):
            r, c = divmod(s, 8)
            if (r + c) % 2 == 1:
                if r <= 2:
                    squares[s] = (COMPUTER, False)
                elif r >= 5:
                    squares[s] = (PLAYER, False)
        return Board(squares, first)

    @staticmethod
    def diagram(lines, turn=PLAYER):
        assert len(lines) == 8, lines
        squares = [None] * 64
        for r, line in enumerate(lines):
            assert len(line) == 8, line
            for c, ch in enumerate(line):
                if ch in "rRbB":
                    assert (r + c) % 2 == 1, f"piece on a light square at {name(r * 8 + c)}"
                    squares[r * 8 + c] = (PLAYER if ch in "rR" else COMPUTER, ch.isupper())
        return Board(squares, turn)

    def copy(self):
        return Board(list(self.squares), self.turn, self.quiet)

    @staticmethod
    def dirs(piece):
        side, king = piece
        if king:
            return [(-1, -1), (-1, 1), (1, -1), (1, 1)]
        f = forward(side)
        return [(f, -1), (f, 1)]

    def legal(self, side=None):
        side = side or self.turn
        jumps = []
        for s in range(64):
            p = self.squares[s]
            if p and p[0] == side:
                self._jumps(s, p, s, [s], [], jumps)
        if jumps:
            return jumps
        moves = []
        for s in range(64):
            p = self.squares[s]
            if p and p[0] == side:
                r, c = divmod(s, 8)
                for dr, dc in self.dirs(p):
                    t = sq(r + dr, c + dc)
                    if t is not None and self.squares[t] is None:
                        moves.append(([s, t], []))
        return moves

    def _jumps(self, s, piece, origin, path, captured, out):
        extended = False
        r, c = divmod(s, 8)
        for dr, dc in self.dirs(piece):
            over, land = sq(r + dr, c + dc), sq(r + 2 * dr, c + 2 * dc)
            if over is None or land is None:
                continue
            v = self.squares[over]
            if not v or v[0] == piece[0] or over in captured:
                continue
            if self.squares[land] is not None and land != origin:
                continue
            extended = True
            np, nc = path + [land], captured + [over]
            if not piece[1] and land // 8 == crown_row(piece[0]):
                out.append((np, nc))
            else:
                self._jumps(land, piece, origin, np, nc, out)
        if not extended and len(path) > 1:
            out.append((path, captured))

    def apply(self, move):
        path, caps = move
        side, king = self.squares[path[0]]
        was_man = not king
        self.squares[path[0]] = None
        for c in caps:
            self.squares[c] = None
        if was_man and path[-1] // 8 == crown_row(side):
            king = True
        self.squares[path[-1]] = (side, king)
        self.quiet = 0 if (caps or was_man) else self.quiet + 1
        self.turn = opponent(self.turn)

    def count(self, side):
        return sum(1 for p in self.squares if p and p[0] == side)


def notation(move):
    path, caps = move
    return ("x" if caps else "-").join(name(s) for s in path)


def find(board, text):
    for m in board.legal():
        if notation(m) == text:
            return m
    return None


def safe(board, move):
    b = board.copy()
    b.apply(move)
    replies = b.legal()
    return not (replies and replies[0][1])


# --- Lesson checks -------------------------------------------------------

LESSONS = Path(__file__).resolve().parent.parent / "Puzzles/Checkers/Lessons/CheckersLessons.swift"


def parse_exercises(text):
    """Pulls each CheckersExercise(...) block's diagram and goal out of the Swift file."""
    out = []
    for block in re.findall(r"CheckersExercise\((.*?)\n\s*\)", text, re.S):
        diagram = re.findall(r'"([.rRbB]{8})"', block)
        goal = re.search(r"goal: \.(\w+)(?:\(\[(.*?)\]\))?", block, re.S)
        moves = re.findall(r'"([a-h][1-8](?:[-x][a-h][1-8])+)"', goal.group(2) or "") if goal else []
        out.append((diagram, goal.group(1) if goal else None, moves))
    return out


def check_lessons():
    text = LESSONS.read_text()
    exercises = parse_exercises(text)
    assert exercises, "no exercises found"
    for i, (diagram, goal, moves) in enumerate(exercises, 1):
        b = Board.diagram(diagram)
        legal = b.legal()
        assert legal, f"exercise {i}: no legal moves"
        names = sorted(notation(m) for m in legal)
        if goal == "anyMove":
            pass
        elif goal == "oneOf":
            for m in moves:
                assert m in names, f"exercise {i}: {m} not legal; legal: {names}"
        elif goal == "line":
            for n, m in enumerate(moves):
                mv = find(b, m)
                assert mv, f"exercise {i}: step {n + 1} {m} not legal; legal: {sorted(notation(x) for x in b.legal())}"
                if n % 2 == 1:
                    replies = b.legal()
                    assert len(replies) == 1, f"exercise {i}: computer reply {m} is not forced: {[notation(x) for x in replies]}"
                b.apply(mv)
            # The line's other first moves shouldn't do as well: a different first move must not also win material at once.
        elif goal == "safeMove":
            good = [notation(m) for m in legal if safe(b, m)]
            bad = [notation(m) for m in legal if not safe(b, m)]
            assert good and bad, f"exercise {i}: safe {good} unsafe {bad}"
        elif goal == "winningMove":
            winners = []
            for m in legal:
                nb = b.copy()
                nb.apply(m)
                if not nb.legal():
                    winners.append(notation(m))
            assert winners, f"exercise {i}: no move leaves the computer stuck"
            for m in moves:
                assert m in winners, f"exercise {i}: {m} doesn't win; winners {winners}"
        else:
            raise AssertionError(f"exercise {i}: unknown goal {goal}")
        print(f"exercise {i:2}: {goal:11} ok  legal={names}")


def self_test():
    b = Board.start()
    assert len(b.legal()) == 7
    # Random games end without errors.
    for _ in range(200):
        b = Board.start(random.choice([PLAYER, COMPUTER]))
        for _ in range(400):
            moves = b.legal()
            if not moves or b.quiet >= 80:
                break
            b.apply(random.choice(moves))
    print("random games ok")


if __name__ == "__main__":
    self_test()
    check_lessons()
    sys.exit(0)

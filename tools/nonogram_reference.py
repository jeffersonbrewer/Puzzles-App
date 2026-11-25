"""Python mirror of the Nonograms engine (Puzzles/Nonograms/Engine).

Used to check that every built-in picture can be solved one line at a time
(so it has exactly one answer and never needs guessing), and to write
Puzzles/Nonograms/Engine/NonogramLibrary.swift.

Cell states: 0 = unknown, 1 = filled, 2 = crossed (known empty).
"""

UNKNOWN, FILLED, CROSSED = 0, 1, 2


def clues_for(line):
    out, run = [], 0
    for v in line:
        if v:
            run += 1
        elif run:
            out.append(run)
            run = 0
    if run:
        out.append(run)
    return out


def solve_line(clues, state):
    """Returns the line with every forced cell filled in, or None if the
    clues can't fit the line."""
    n, k = len(state), len(clues)
    can_fill = [s != CROSSED for s in state]
    can_empty = [s != FILLED for s in state]
    # run[i] = how many cells from i onward could be filled in a row
    run = [0] * (n + 1)
    for i in range(n - 1, -1, -1):
        run[i] = run[i + 1] + 1 if can_fill[i] else 0

    # F[i][j]: the first i cells fit the first j clues
    F = [[False] * (k + 1) for _ in range(n + 1)]
    F[0][0] = True
    for i in range(1, n + 1):
        for j in range(k + 1):
            ok = can_empty[i - 1] and F[i - 1][j]
            if not ok and j >= 1:
                L = clues[j - 1]
                s = i - L
                if s >= 0 and run[s] >= L:
                    if j == 1:
                        ok = F[s][0]
                    else:
                        ok = s >= 1 and can_empty[s - 1] and F[s - 1][j - 1]
            F[i][j] = ok

    # B[i][j]: the cells from i onward fit clues j and later
    B = [[False] * (k + 1) for _ in range(n + 2)]
    B[n][k] = True
    for i in range(n - 1, -1, -1):
        for j in range(k, -1, -1):
            ok = can_empty[i] and B[i + 1][j]
            if not ok and j < k:
                L = clues[j]
                if run[i] >= L:
                    e = i + L
                    if j == k - 1:
                        ok = B[e][k]
                    else:
                        ok = e < n and can_empty[e] and B[e + 1][j + 1]
            B[i][j] = ok

    if not F[n][k]:
        return None

    may_empty = [False] * n
    may_fill = [False] * n
    for x in range(n):
        if can_empty[x]:
            may_empty[x] = any(F[x][j] and B[x + 1][j] for j in range(k + 1))
    for j in range(k):
        L = clues[j]
        for s in range(0, n - L + 1):
            if run[s] < L:
                continue
            left = F[s][0] if j == 0 else (s >= 1 and can_empty[s - 1] and F[s - 1][j])
            if not left:
                continue
            e = s + L
            right = B[e][k] if j == k - 1 else (e < n and can_empty[e] and B[e + 1][j + 1])
            if right:
                for x in range(s, e):
                    may_fill[x] = True

    out = list(state)
    for x in range(n):
        if out[x] == UNKNOWN:
            if may_fill[x] and not may_empty[x]:
                out[x] = FILLED
            elif may_empty[x] and not may_fill[x]:
                out[x] = CROSSED
    return out


def solve(rows, cols):
    """Line-by-line solve. Returns (grid, solved)."""
    h, w = len(rows), len(cols)
    g = [[UNKNOWN] * w for _ in range(h)]
    changed = True
    while changed:
        changed = False
        for r in range(h):
            new = solve_line(rows[r], g[r])
            if new is None:
                return g, False
            if new != g[r]:
                g[r] = new
                changed = True
        for c in range(w):
            col = [g[r][c] for r in range(h)]
            new = solve_line(cols[c], col)
            if new is None:
                return g, False
            if new != col:
                for r in range(h):
                    g[r][c] = new[r]
                changed = True
    return g, all(v != UNKNOWN for row in g for v in row)


def parse(art):
    lines = [l.strip() for l in art.strip().splitlines()]
    return [[1 if ch == '#' else 0 for ch in l] for l in lines]


def clues_of(grid):
    rows = [clues_for(r) for r in grid]
    cols = [clues_for([grid[r][c] for r in range(len(grid))]) for c in range(len(grid[0]))]
    return rows, cols


def line_solvable(grid):
    rows, cols = clues_of(grid)
    g, ok = solve(rows, cols)
    return ok and all((g[r][c] == FILLED) == bool(grid[r][c]) for r in range(len(grid)) for c in range(len(grid[0])))


if __name__ == '__main__':
    import random
    assert solve_line([3], [0] * 5) == [0, 0, 1, 0, 0]
    assert solve_line([], [0] * 3) == [2, 2, 2]
    assert solve_line([2, 1], [0] * 4) == [1, 1, 2, 1]
    assert solve_line([1], [0, 1, 0]) == [2, 1, 2]
    assert solve_line([2], [1, 2, 0]) is None
    # Brute-force check of the line solver on random lines.
    from itertools import product
    rng = random.Random(3)
    for _ in range(3000):
        n = rng.randint(1, 9)
        sol = [rng.random() < 0.55 for _ in range(n)]
        cl = clues_for(sol)
        st = [rng.choice([0, 0, 0, 1 if sol[i] else 2]) for i in range(n)]
        fits = [p for p in product([0, 1], repeat=n)
                if clues_for(p) == cl and all(s == 0 or (s == 1) == bool(p[i]) for i, s in enumerate(st))]
        want = list(st)
        for i in range(n):
            if st[i] == 0:
                vals = {p[i] for p in fits}
                if vals == {1}:
                    want[i] = 1
                elif vals == {0}:
                    want[i] = 2
        assert solve_line(cl, st) == want, (cl, st, want, solve_line(cl, st))
    print('line solver OK')

import Foundation

/// The tiles still on the table, one entry per slot of the layout (nil once removed).
struct MahjongBoard: Codable, Equatable {
    let layoutID: String
    var tiles: [MahjongTile?]

    var layout: MahjongLayout { MahjongLayout.named(layoutID) }
    var remaining: Int { tiles.reduce(0) { $0 + ($1 == nil ? 0 : 1) } }
    var isCleared: Bool { tiles.allSatisfy { $0 == nil } }

    func isFree(_ i: Int) -> Bool {
        guard tiles[i] != nil else { return false }
        return layout.isFree(i) { j in tiles[j] != nil }
    }

    /// True when another tile rests on this one.
    func isCovered(_ i: Int) -> Bool {
        layout.above[i].contains { j in tiles[j] != nil }
    }

    /// Every pair of free tiles that match, as slot indices.
    func openPairs() -> [(Int, Int)] {
        let layout = self.layout
        let free = tiles.indices.filter { i in
            tiles[i] != nil && layout.isFree(i) { j in tiles[j] != nil }
        }
        var pairs: [(Int, Int)] = []
        for (n, a) in free.enumerated() {
            for b in free[(n + 1)...] where tiles[a]!.matches(tiles[b]!) {
                pairs.append((a, b))
            }
        }
        return pairs
    }

    func canRemove(_ a: Int, _ b: Int) -> Bool {
        guard a != b, isFree(a), isFree(b), let ta = tiles[a], let tb = tiles[b] else { return false }
        return ta.matches(tb)
    }

    mutating func remove(_ a: Int, _ b: Int) {
        tiles[a] = nil
        tiles[b] = nil
    }

    // MARK: - Dealing

    /// A new deal that can always be cleared: the tiles are placed by playing a
    /// random game backwards, so the reverse of that order is a winning line.
    static func deal(_ layout: MahjongLayout) -> MahjongBoard {
        let count = layout.tileCount
        let pairs = MahjongTile.pairs(count: count / 2)
        var board = MahjongBoard(layoutID: layout.id, tiles: Array(repeating: nil, count: count))
        board.place(pairs, on: Array(repeating: true, count: count))
        return board
    }

    /// The same tiles moved to new spots among the ones still filled, again
    /// arranged so the rest can be cleared when the shape allows it.
    func reshuffled() -> MahjongBoard {
        var groups: [Int: [MahjongTile]] = [:]
        for tile in tiles.compactMap({ $0 }) { groups[tile.matchKey, default: []].append(tile) }
        var pairs: [(MahjongTile, MahjongTile)] = []
        for group in groups.values {
            let shuffled = group.shuffled()
            for i in stride(from: 0, to: shuffled.count - 1, by: 2) {
                pairs.append((shuffled[i], shuffled[i + 1]))
            }
        }
        pairs.shuffle()
        var next = self
        next.place(pairs, on: tiles.map { $0 != nil })
        return next
    }

    /// Puts each pair on two slots that would be free together, in a random
    /// removal order of the `occupied` slots. Falls back to a plain shuffle if
    /// no such order turns up (only possible for odd leftovers, like one tile
    /// stuck under its own match).
    private mutating func place(_ pairs: [(MahjongTile, MahjongTile)], on occupied: [Bool]) {
        let layout = self.layout
        for i in tiles.indices { tiles[i] = nil }
        let order = (0..<400).lazy
            .compactMap { _ in Self.removalOrder(layout, occupied: occupied) }
            .first { $0.count == pairs.count }
        if let order {
            for (pair, slots) in zip(pairs, order) {
                tiles[slots.0] = pair.0
                tiles[slots.1] = pair.1
            }
        } else {
            let open = occupied.indices.filter { occupied[$0] }.shuffled()
            let flat = pairs.flatMap { [$0.0, $0.1] }
            for (slot, tile) in zip(open, flat) { tiles[slot] = tile }
        }
    }

    /// Removes random pairs of free slots until none are left, or returns nil
    /// if it gets stuck.
    private static func removalOrder(_ layout: MahjongLayout, occupied start: [Bool]) -> [(Int, Int)]? {
        var occupied = start
        var left = occupied.filter { $0 }.count
        var order: [(Int, Int)] = []
        while left > 0 {
            let free = occupied.indices.filter { i in
                occupied[i] && layout.isFree(i) { j in occupied[j] }
            }
            guard free.count >= 2 else { return nil }
            let picked = free.shuffled()
            occupied[picked[0]] = false
            occupied[picked[1]] = false
            order.append((picked[0], picked[1]))
            left -= 2
        }
        return order
    }
}

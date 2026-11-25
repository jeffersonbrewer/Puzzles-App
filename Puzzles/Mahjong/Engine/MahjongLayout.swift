import Foundation

/// Where a tile sits. `x` and `y` are in half-tile steps (a tile covers
/// x...x+2 and y...y+2), so tiles can sit half over their neighbors.
/// `z` is the layer, 0 at the bottom.
struct TileSlot: Hashable {
    let x: Int
    let y: Int
    let z: Int
}

/// A tile arrangement. The layouts are original, shaped to fit a phone held upright.
struct MahjongLayout: Identifiable {
    /// One layer of tiles. In `rows`, each "X" is a tile and "." a gap, one
    /// character per tile width; `dx`/`dy` shift the whole layer by half tiles.
    struct Layer {
        let points: [(x: Int, y: Int)]

        init(dx: Int = 0, dy: Int = 0, _ rows: [String]) {
            var points: [(x: Int, y: Int)] = []
            for (r, row) in rows.enumerated() {
                for (c, ch) in row.enumerated() where ch == "X" {
                    points.append((x: 2 * c + dx, y: 2 * r + dy))
                }
            }
            self.points = points
        }

        /// Tiles at explicit half-tile positions.
        init(points: [(x: Int, y: Int)]) { self.points = points }
    }

    let id: String
    let name: String
    let blurb: String
    /// In drawing order: bottom layer first, then top to bottom, left to right.
    let slots: [TileSlot]
    /// Size of the layout in half tiles.
    let columns: Int
    let rows: Int
    /// The highest layer.
    let depth: Int
    /// For each slot, the slots that rest on it (any part of them).
    let above: [[Int]]
    /// For each slot, the slots touching its left or right edge on the same layer.
    let left: [[Int]]
    let right: [[Int]]

    var tileCount: Int { slots.count }

    init(id: String, name: String, blurb: String, layers: [Layer]) {
        var all: [TileSlot] = []
        for (z, layer) in layers.enumerated() {
            for p in layer.points { all.append(TileSlot(x: p.x, y: p.y, z: z)) }
        }
        all.sort { ($0.z, $0.y, $0.x) < ($1.z, $1.y, $1.x) }
        let slots = all
        self.id = id
        self.name = name
        self.blurb = blurb
        self.slots = slots
        columns = (slots.map(\.x).max() ?? 0) + 2
        rows = (slots.map(\.y).max() ?? 0) + 2
        depth = slots.map(\.z).max() ?? 0
        above = slots.map { s in
            slots.indices.filter { j in slots[j].z > s.z && abs(slots[j].x - s.x) < 2 && abs(slots[j].y - s.y) < 2 }
        }
        left = slots.map { s in
            slots.indices.filter { j in slots[j].z == s.z && slots[j].x == s.x - 2 && abs(slots[j].y - s.y) < 2 }
        }
        right = slots.map { s in
            slots.indices.filter { j in slots[j].z == s.z && slots[j].x == s.x + 2 && abs(slots[j].y - s.y) < 2 }
        }
    }

    /// A tile is free when nothing rests on it and its left or right side is open.
    func isFree(_ i: Int, occupied: (Int) -> Bool) -> Bool {
        if above[i].contains(where: occupied) { return false }
        return !left[i].contains(where: occupied) || !right[i].contains(where: occupied)
    }

    // MARK: - The layouts

    static let garden = MahjongLayout(
        id: "garden",
        name: "Garden",
        blurb: "72 tiles, three layers. A quick game.",
        layers: [
            Layer([
                "..XXXX..",
                ".XXXXXX.",
                "XXXXXXXX",
                "XXXXXXXX",
                "XXXXXXXX",
                "XXXXXXXX",
                ".XXXXXX.",
                "..XXXX..",
            ]),
            Layer(dx: 4, dy: 4, Array(repeating: "XXXX", count: 4)),
            Layer(dx: 6, dy: 6, ["XX", "XX"]),
        ]
    )

    static let fortress = MahjongLayout(
        id: "fortress",
        name: "Fortress",
        blurb: "86 tiles. Four corner towers around a keep.",
        layers: [
            Layer([
                "XXX..XXX",
                "XXX..XXX",
                "XXXXXXXX",
                "XXXXXXXX",
                "XXXXXXXX",
                "XXXXXXXX",
                "XXX..XXX",
                "XXX..XXX",
            ]),
            Layer([
                "XX....XX",
                "XX....XX",
                "........",
                "..XXXX..",
                "..XXXX..",
                "........",
                "XX....XX",
                "XX....XX",
            ]),
            Layer(points: [(1, 1), (13, 1), (1, 13), (13, 13), (6, 7), (8, 7)]),
        ]
    )

    static let pagoda = MahjongLayout(
        id: "pagoda",
        name: "Pagoda",
        blurb: "All 144 tiles, stacked four high.",
        layers: [
            Layer([
                ".XXXXXX.",
                "XXXXXXXX",
                "XXXXXXXX",
                ".XXXXXX.",
                "XXXXXXXX",
                "XXXXXXXX",
                ".XXXXXX.",
                "XXXXXXXX",
                "XXXXXXXX",
                ".XXXXXX.",
            ]),
            Layer(dx: 2, dy: 2, Array(repeating: "XXXXXX", count: 8)),
            Layer(dx: 4, dy: 5, Array(repeating: "XXXX", count: 5)),
            Layer(dx: 6, dy: 8, ["XX", "XX"]),
        ]
    )

    static let all: [MahjongLayout] = [garden, fortress, pagoda]

    static func named(_ id: String) -> MahjongLayout {
        all.first { $0.id == id } ?? garden
    }
}

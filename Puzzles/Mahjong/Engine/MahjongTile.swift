import Foundation

/// One of the 42 tile designs. Codes 0-33 (the three suits, winds and dragons)
/// come in sets of four identical tiles. Codes 34-37 are the four flowers and
/// 38-41 the four seasons: each is a single tile, and any flower matches any
/// other flower (the same for seasons).
struct MahjongTile: Hashable, Codable {
    let code: Int

    init(_ code: Int) { self.code = code }

    enum Kind: Equatable {
        /// 1...9
        case dots(Int)
        case bamboo(Int)
        case characters(Int)
        /// 0 east, 1 south, 2 west, 3 north
        case wind(Int)
        /// 0 red, 1 green, 2 white
        case dragon(Int)
        /// 0 plum, 1 orchid, 2 chrysanthemum, 3 lotus
        case flower(Int)
        /// 0 spring, 1 summer, 2 autumn, 3 winter
        case season(Int)
    }

    var kind: Kind {
        switch code {
        case 0..<9: return .dots(code + 1)
        case 9..<18: return .bamboo(code - 8)
        case 18..<27: return .characters(code - 17)
        case 27..<31: return .wind(code - 27)
        case 31..<34: return .dragon(code - 31)
        case 34..<38: return .flower(code - 34)
        default: return .season(code - 38)
        }
    }

    /// Tiles with the same key can be removed together.
    var matchKey: Int {
        switch code {
        case 34..<38: return 34
        case 38..<42: return 38
        default: return code
        }
    }

    func matches(_ other: MahjongTile) -> Bool { matchKey == other.matchKey }

    var name: String {
        switch kind {
        case .dots(let n): return "\(n) of Dots"
        case .bamboo(let n): return "\(n) of Bamboo"
        case .characters(let n): return "\(n) of Characters"
        case .wind(let i): return ["East", "South", "West", "North"][i] + " Wind"
        case .dragon(let i): return ["Red", "Green", "White"][i] + " Dragon"
        case .flower(let i): return ["Plum", "Orchid", "Chrysanthemum", "Lotus"][i] + " flower"
        case .season(let i): return ["Spring", "Summer", "Autumn", "Winter"][i]
        }
    }

    /// A short name for hints, like "Dots" or "Flowers", used when the two
    /// tiles of a pair can differ.
    var groupName: String {
        switch kind {
        case .flower: return "two flowers"
        case .season: return "two seasons"
        default: return "the two \(name) tiles"
        }
    }

    // Stored as a bare number to keep saved games small.
    init(from decoder: Decoder) throws {
        code = try decoder.singleValueContainer().decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(code)
    }

    /// `count` matching pairs drawn at random from the full 144-tile set
    /// (72 pairs). Smaller layouts use a random part of the set.
    static func pairs(count: Int) -> [(MahjongTile, MahjongTile)] {
        var all: [(MahjongTile, MahjongTile)] = []
        for code in 0..<34 {
            let tile = MahjongTile(code)
            all.append((tile, tile))
            all.append((tile, tile))
        }
        for base in [34, 38] {
            let group = (base..<base + 4).map { MahjongTile($0) }.shuffled()
            all.append((group[0], group[1]))
            all.append((group[2], group[3]))
        }
        all.shuffle()
        return Array(all.prefix(count))
    }
}

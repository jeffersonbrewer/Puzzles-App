import Foundation

enum Suit: Int, CaseIterable {
    case spades, hearts, clubs, diamonds

    var isRed: Bool { self == .hearts || self == .diamonds }

    var name: String {
        switch self {
        case .spades: return "spades"
        case .hearts: return "hearts"
        case .clubs: return "clubs"
        case .diamonds: return "diamonds"
        }
    }

    /// SF Symbol used to draw the suit.
    var symbol: String {
        switch self {
        case .spades: return "suit.spade.fill"
        case .hearts: return "suit.heart.fill"
        case .clubs: return "suit.club.fill"
        case .diamonds: return "suit.diamond.fill"
        }
    }
}

/// One of the 52 cards. Stored as a single number so saved games stay small.
struct Card: Hashable, Identifiable {
    let id: Int

    init(id: Int) { self.id = id }
    init(_ suit: Suit, _ rank: Int) { id = suit.rawValue * 13 + rank - 1 }

    var suit: Suit { Suit(rawValue: id / 13)! }
    /// 1 (ace) ... 13 (king)
    var rank: Int { id % 13 + 1 }
    var isRed: Bool { suit.isRed }

    var rankLabel: String {
        switch rank {
        case 1: return "A"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        default: return "\(rank)"
        }
    }

    var name: String {
        let rankName: String
        switch rank {
        case 1: rankName = "Ace"
        case 11: rankName = "Jack"
        case 12: rankName = "Queen"
        case 13: rankName = "King"
        default: rankName = "\(rank)"
        }
        return "\(rankName) of \(suit.name)"
    }

    static let deck: [Card] = (0..<52).map { Card(id: $0) }
}

extension Card: Codable {
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(Int.self)
        guard (0..<52).contains(value) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a card: \(value)"))
        }
        id = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

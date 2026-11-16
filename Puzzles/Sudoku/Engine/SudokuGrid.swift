import Foundation

/// Static geometry and helpers for a 9x9 Sudoku grid.
///
/// Cells are indexed 0...80, row by row. Houses (rows, columns and boxes) are
/// indexed 0...26: rows are 0-8, columns are 9-17 and boxes are 18-26.
enum Sudoku {
    static let cellCount = 81
    static let allCandidates: UInt16 = 0b11_1111_1110 // bits 1...9

    static func row(_ cell: Int) -> Int { cell / 9 }
    static func col(_ cell: Int) -> Int { cell % 9 }
    static func box(_ cell: Int) -> Int { (cell / 27) * 3 + (cell % 9) / 3 }

    static func rowHouse(_ cell: Int) -> Int { row(cell) }
    static func colHouse(_ cell: Int) -> Int { 9 + col(cell) }
    static func boxHouse(_ cell: Int) -> Int { 18 + box(cell) }

    static let houses: [[Int]] = {
        var result: [[Int]] = []
        for r in 0..<9 { result.append((0..<9).map { r * 9 + $0 }) }
        for c in 0..<9 { result.append((0..<9).map { $0 * 9 + c }) }
        for b in 0..<9 {
            result.append((0..<9).map { k in (b / 3) * 27 + (b % 3) * 3 + (k / 3) * 9 + k % 3 })
        }
        return result
    }()

    static let peers: [[Int]] = (0..<81).map { cell in
        var set = Set<Int>()
        set.formUnion(houses[rowHouse(cell)])
        set.formUnion(houses[colHouse(cell)])
        set.formUnion(houses[boxHouse(cell)])
        set.remove(cell)
        return set.sorted()
    }

    static let peerSets: [Set<Int>] = peers.map { Set($0) }

    static func sees(_ a: Int, _ b: Int) -> Bool { a != b && peerSets[a].contains(b) }

    static func bit(_ digit: Int) -> UInt16 { UInt16(1) << UInt16(digit) }

    // MARK: Human-readable names (1-based)

    static func cellName(_ cell: Int) -> String { "R\(row(cell) + 1)C\(col(cell) + 1)" }

    static func houseName(_ house: Int) -> String {
        switch house {
        case 0..<9: return "row \(house + 1)"
        case 9..<18: return "column \(house - 8)"
        default: return "box \(house - 17)"
        }
    }

    static func houseKind(_ house: Int) -> String {
        switch house {
        case 0..<9: return "row"
        case 9..<18: return "column"
        default: return "box"
        }
    }

    static func cellList(_ cells: [Int]) -> String {
        listText(cells.sorted().map(cellName))
    }

    static func listText(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default: return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }

    /// Parses an 81-character string of digits (0 or . for empty).
    static func parse(_ text: String) -> [Int] {
        text.compactMap { ch -> Int? in
            if ch == "." { return 0 }
            return ch.wholeNumberValue
        }
    }
}

extension UInt16 {
    /// Digits (1...9) whose bits are set.
    var digits: [Int] { (1...9).filter { self & Sudoku.bit($0) != 0 } }
    var count: Int { nonzeroBitCount }
    func has(_ digit: Int) -> Bool { self & Sudoku.bit(digit) != 0 }
}

/// A candidate digit in a specific cell.
struct CellDigit: Hashable, Codable {
    let cell: Int
    let digit: Int
}

/// Returns all k-element combinations of `items`, preserving order.
func combinations<T>(_ items: [T], _ k: Int) -> [[T]] {
    guard k > 0 else { return [[]] }
    guard items.count >= k else { return [] }
    var result: [[T]] = []
    var current: [T] = []
    func walk(_ start: Int) {
        if current.count == k { result.append(current); return }
        let needed = k - current.count
        guard start <= items.count - needed else { return }
        for i in start...(items.count - needed) {
            current.append(items[i])
            walk(i + 1)
            current.removeLast()
        }
    }
    walk(0)
    return result
}

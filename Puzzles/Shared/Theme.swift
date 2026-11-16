import SwiftUI

/// App-wide colors. The accent color itself lives in Assets (AccentColor).
enum Theme {
    static let accent = Color.accentColor
    static let selectedCell = Color.accentColor.opacity(0.38)
    static let sameDigit = Color.accentColor.opacity(0.22)
    static let peerCell = Color.accentColor.opacity(0.08)
    static let wrongText = Color(red: 0.86, green: 0.20, blue: 0.24)
    static let wrongCell = Color(red: 0.86, green: 0.20, blue: 0.24).opacity(0.14)
    static let patternCell = Color(red: 0.98, green: 0.72, blue: 0.20).opacity(0.38)
    static let houseShade = Color(red: 0.98, green: 0.72, blue: 0.20).opacity(0.12)
    static let patternCandidate = Color(red: 0.80, green: 0.45, blue: 0.00)
    static let elimination = Color(red: 0.86, green: 0.20, blue: 0.24)
    static let placement = Color(red: 0.15, green: 0.62, blue: 0.35)
    static let gridLine = Color.primary.opacity(0.22)
    static let boxLine = Color.primary.opacity(0.75)
    static let card = Color(.secondarySystemBackground)
}

func formatTime(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%d:%02d", m, s)
}

import SwiftUI
import UIKit

/// Card colors, adapted for light and dark mode.
enum CardColors {
    static let face = adaptive(light: UIColor(white: 1, alpha: 1), dark: UIColor(white: 0.17, alpha: 1))
    static let edge = adaptive(light: UIColor(white: 0, alpha: 0.28), dark: UIColor(white: 1, alpha: 0.34))
    static let black = adaptive(light: UIColor(white: 0.10, alpha: 1), dark: UIColor(white: 0.95, alpha: 1))
    static let red = adaptive(
        light: UIColor(red: 0.80, green: 0.12, blue: 0.16, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.45, blue: 0.45, alpha: 1)
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// A playing card drawn in SwiftUI. Everything scales with `width`.
struct CardView: View {
    @Environment(\.palette) private var palette
    let card: Card
    let faceUp: Bool
    let width: CGFloat
    var highlighted = false

    static func height(forWidth width: CGFloat) -> CGFloat { width * 1.42 }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: width * 0.12, style: .continuous) }

    var body: some View {
        ZStack {
            if faceUp { face } else { back }
        }
        .frame(width: width, height: Self.height(forWidth: width))
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(highlighted ? Theme.patternCandidate : CardColors.edge, lineWidth: highlighted ? 3 : 0.75)
        }
        .contentShape(shape)
        .accessibilityElement()
        .accessibilityLabel(faceUp ? card.name : "Face-down card")
        .accessibilityAddTraits(.isButton)
    }

    private var face: some View {
        ZStack {
            CardColors.face
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text(card.rankLabel)
                        .font(.system(size: width * 0.40, weight: .bold, design: .rounded))
                        .kerning(card.rank == 10 ? -width * 0.04 : 0)
                        .lineLimit(1)
                        .fixedSize()
                    Spacer(minLength: 0)
                    Image(systemName: card.suit.symbol)
                        .font(.system(size: width * 0.27))
                }
                .padding(.horizontal, width * 0.08)
                .frame(height: width * 0.46)
                Image(systemName: card.suit.symbol)
                    .font(.system(size: width * 0.54))
                    .frame(maxHeight: .infinity)
                    .padding(.bottom, width * 0.06)
            }
            .foregroundStyle(card.isRed ? CardColors.red : CardColors.black)
        }
    }

    private var back: some View {
        ZStack {
            CardColors.face
            RoundedRectangle(cornerRadius: width * 0.08, style: .continuous)
                .fill(palette.accent.gradient)
                .overlay {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: width * 0.34))
                        .foregroundStyle(.white.opacity(0.28))
                }
                .padding(width * 0.06)
        }
    }
}

/// The outline of an empty pile.
struct CardSlot: View {
    let symbol: String?
    let width: CGFloat
    var highlighted = false

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
            .strokeBorder(highlighted ? Theme.patternCandidate : Color.primary.opacity(0.25), lineWidth: highlighted ? 3 : 1)
            .background {
                RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            }
            .overlay {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: width * 0.42))
                        .foregroundStyle(Color.primary.opacity(0.22))
                }
            }
            .frame(width: width, height: CardView.height(forWidth: width))
    }
}

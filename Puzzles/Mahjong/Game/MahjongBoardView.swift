import SwiftUI

/// Tile size and where each tile sits, for a layout and the space it gets.
struct MahjongMetrics {
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    /// How far each layer is lifted up and to the left.
    let lift: CGFloat
    /// How much of a tile's sides shows.
    let depth: CGFloat
    private let origin: CGPoint

    static let aspect: CGFloat = 1.3
    private static let liftShare: CGFloat = 0.09
    private static let depthShare: CGFloat = 0.10
    private static let margin: CGFloat = 8

    init(layout: MahjongLayout, size: CGSize) {
        let across = CGFloat(layout.columns) / 2
        let down = CGFloat(layout.rows) / 2
        let layers = CGFloat(layout.depth)
        let extra = layers * Self.liftShare + Self.depthShare
        let usable = CGSize(width: max(1, size.width - 2 * Self.margin), height: max(1, size.height - 2 * Self.margin))
        let width = min(usable.width / (across + extra), usable.height / (down * Self.aspect + extra), 80)
        tileWidth = width
        tileHeight = width * Self.aspect
        lift = width * Self.liftShare
        depth = width * Self.depthShare
        let total = CGSize(width: across * width + layers * lift + depth, height: down * tileHeight + layers * lift + depth)
        origin = CGPoint(x: (size.width - total.width) / 2 + layers * lift, y: (size.height - total.height) / 2 + layers * lift)
    }

    /// The face of the tile in a slot.
    func face(_ slot: TileSlot) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(slot.x) / 2 * tileWidth - CGFloat(slot.z) * lift,
            y: origin.y + CGFloat(slot.y) / 2 * tileHeight - CGFloat(slot.z) * lift,
            width: tileWidth,
            height: tileHeight
        )
    }
}

/// The table. Each tile is a view in drawing order, so a tile higher up or
/// nearer the bottom right covers the ones it overlaps.
struct MahjongBoardView: View {
    @ObservedObject var game: MahjongGame
    @AppStorage(MahjongSettings.dimBlockedKey) private var dimBlocked = true

    var body: some View {
        GeometryReader { geo in
            let board = game.board
            let layout = board.layout
            let metrics = MahjongMetrics(layout: layout, size: geo.size)
            ZStack(alignment: .topLeading) {
                ForEach(layout.slots.indices.filter { board.tiles[$0] != nil }, id: \.self) { i in
                    tileView(i, board: board, layout: layout, metrics: metrics)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: game.moves)
        .sensoryFeedback(.selection, trigger: game.selected)
        .sensoryFeedback(.warning, trigger: game.rejections)
    }

    @ViewBuilder
    private func tileView(_ i: Int, board: MahjongBoard, layout: MahjongLayout, metrics: MahjongMetrics) -> some View {
        if let tile = board.tiles[i] {
            let face = metrics.face(layout.slots[i])
            let free = board.isFree(i)
            let state = TileState(
                selected: game.selected == i,
                hinted: game.hint?.slots.contains(i) ?? false,
                dimmed: dimBlocked && !free,
                rejected: game.rejected == i
            )
            let status: String = free ? (state.selected ? "Selected" : "Free") : "Blocked"
            MahjongTileView(tile: tile, width: metrics.tileWidth, height: metrics.tileHeight, depth: metrics.depth, state: state)
                .position(x: face.minX + (metrics.tileWidth + metrics.depth) / 2,
                          y: face.minY + (metrics.tileHeight + metrics.depth) / 2)
                .zIndex(Double(i))
                .transition(.scale(scale: 0.7).combined(with: .opacity))
                .onTapGesture { game.tap(i) }
                .accessibilityElement()
                .accessibilityLabel(tile.name)
                .accessibilityValue(Text(status))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { game.tap(i) }
                .accessibilityHidden(board.isCovered(i))
        }
    }
}

enum MahjongSettings {
    static let dimBlockedKey = "mahjong.dimBlocked"
}

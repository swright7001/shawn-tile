import Foundation
import CoreGraphics

public enum Layout: String, Codable, CaseIterable { case automatic, grid, columns, rows }
public struct DisplaySettings: Codable, Equatable {
    public var layout: Layout = .automatic
    public var capacity: Int = 3
    public var gap: Double = 10
    public var autoFit: Bool = true
    public init(layout: Layout = .automatic, capacity: Int = 3, gap: Double = 10, autoFit: Bool = true) {
        self.layout = layout; self.capacity = capacity; self.gap = gap; self.autoFit = autoFit
    }
    private enum CodingKeys: String, CodingKey { case layout, capacity, gap, autoFit }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        layout = try values.decodeIfPresent(Layout.self, forKey: .layout) ?? .automatic
        capacity = try values.decodeIfPresent(Int.self, forKey: .capacity) ?? 3
        gap = try values.decodeIfPresent(Double.self, forKey: .gap) ?? 10
        autoFit = try values.decodeIfPresent(Bool.self, forKey: .autoFit) ?? true
    }
}
public enum Geometry {
    public static func resolvedLayout(in area: CGRect, settings: DisplaySettings) -> Layout {
        settings.layout == .automatic ? (area.height > area.width ? .rows : .grid) : settings.layout
    }
    /// All coordinates use Accessibility's global, top-left coordinate system.
    public static func frames(in area: CGRect, count: Int, settings: DisplaySettings) -> [CGRect] {
        guard count > 0, area.width > 0, area.height > 0 else { return [] }
        let n = min(4, count)
        let g = min(max(0, settings.gap), min(area.width, area.height) / 12)
        let box = area.insetBy(dx: g, dy: g)
        let layout = resolvedLayout(in:area,settings:settings)
        let horizontal = layout == .rows
        if layout == .columns || horizontal {
            return (0..<n).map { i in
                if horizontal {
                    let h = (box.height - g * Double(n - 1)) / Double(n)
                    return CGRect(x: box.minX, y: box.minY + Double(i) * (h + g), width: box.width, height: h).integral
                }
                let w = (box.width - g * Double(n - 1)) / Double(n)
                return CGRect(x: box.minX + Double(i) * (w + g), y: box.minY, width: w, height: box.height).integral
            }
        }
        let w = (box.width - g) / 2, h = (box.height - g) / 2
        switch n {
        case 1: return [box.integral]
        case 2: return [CGRect(x: box.minX, y: box.minY, width: w, height: box.height).integral,
                        CGRect(x: box.minX + w + g, y: box.minY, width: w, height: box.height).integral]
        case 3: return [CGRect(x: box.minX, y: box.minY, width: w, height: box.height).integral,
                        CGRect(x: box.minX + w + g, y: box.minY, width: w, height: h).integral,
                        CGRect(x: box.minX + w + g, y: box.minY + h + g, width: w, height: h).integral]
        default: return [CGRect(x: box.minX, y: box.minY, width: w, height: h).integral,
                          CGRect(x: box.minX + w + g, y: box.minY, width: w, height: h).integral,
                          CGRect(x: box.minX + w + g, y: box.minY + h + g, width: w, height: h).integral,
                          CGRect(x: box.minX, y: box.minY + h + g, width: w, height: h).integral]
        }
    }
    public static func axRect(fromCocoa rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
    public static func bestScreen(for window: CGRect, screens: [CGRect]) -> Int? {
        screens.indices.max { a, b in
            let ra = screens[a].intersection(window), rb = screens[b].intersection(window)
            return (ra.isNull ? 0 : ra.width * ra.height) < (rb.isNull ? 0 : rb.width * rb.height)
        }
    }
}

/// Tile membership persists while visible windows exist. Overflow joins the active tile.
public struct TileState: Equatable {
    public private(set) var tiles: [[String]] = []
    public init() {}
    public mutating func reconcile(windows: [String], capacity: Int, focused: String?) {
        let limit = max(1, min(4, capacity))
        let visible = Set(windows)
        tiles = tiles.map { $0.filter(visible.contains) }.filter { !$0.isEmpty }
        while tiles.count > limit {
            let tail = tiles.removeLast(); tiles[tiles.count - 1].append(contentsOf: tail)
        }
        var known = Set(tiles.flatMap { $0 })
        for id in windows where !known.contains(id) {
            if tiles.count < limit { tiles.append([id]) }
            else {
                let slot = focused.flatMap { f in tiles.firstIndex { $0.contains(f) } } ?? tiles.count - 1
                tiles[slot].append(id)
            }
            known.insert(id)
        }
        while tiles.count < limit, let source = tiles.firstIndex(where: { $0.count > 1 }) {
            let id = tiles[source].removeLast(); tiles.append([id])
        }
    }
    public func reordered(_ order:[Int]) -> TileState {
        guard order.count == tiles.count, Set(order) == Set(tiles.indices) else { return self }
        var copy = self; copy.tiles = order.map { tiles[$0] }; return copy
    }
    public func slot(of id: String) -> Int? { tiles.firstIndex { $0.contains(id) } }
    public func next(in id: String, offset: Int = 1) -> String? {
        guard let s = slot(of: id), let i = tiles[s].firstIndex(of: id) else { return nil }
        let t = tiles[s]; return t[(i + offset % t.count + t.count) % t.count]
    }
    public mutating func swap(_ a: String, _ b: String) {
        guard let x = slot(of: a), let y = slot(of: b),
              let i = tiles[x].firstIndex(of: a), let j = tiles[y].firstIndex(of: b), x != y else { return }
        tiles[x][i] = b; tiles[y][j] = a
    }
}

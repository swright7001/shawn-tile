import Foundation
import CoreGraphics

public struct FittedLayout {
    public var state: TileState
    public let frames: [CGRect]
    public let layout: Layout
    public let floating: [String]
}

/// Pure layout planning. Bounds are measured by the AX adapter, never guessed from app names.
public enum AdaptiveLayout {
    public static func plan(in area: CGRect, windows: [String], state: TileState,
                            minimums: [String: CGSize], settings: DisplaySettings, focused: String?) -> FittedLayout {
        guard area.width > 0, area.height > 0, !windows.isEmpty else {
            return FittedLayout(state: TileState(), frames: [], layout: settings.layout, floating: [])
        }
        if !settings.autoFit {
            var fixed = state; fixed.reconcile(windows: windows, capacity: settings.capacity, focused: focused)
            return FittedLayout(state: fixed, frames: Geometry.frames(in: area, count: fixed.tiles.count, settings: settings), layout: Geometry.resolvedLayout(in:area,settings:settings), floating: [])
        }
        let gap = min(max(0, settings.gap), min(area.width, area.height) / 12)
        let floating = windows.filter { id in
            let size = minimums[id] ?? .zero
            return size.width > area.width + 0.01 || size.height > area.height + 0.01
        }
        let fitWindows = windows.filter { !floating.contains($0) }
        guard !fitWindows.isEmpty else {
            return FittedLayout(state: TileState(), frames: [], layout: settings.layout, floating: floating)
        }
        // Explicit layouts keep their shape. Only Auto may choose another arrangement.
        let preferred = Geometry.resolvedLayout(in:area,settings:settings)
        let layouts = settings.layout == .automatic ? [preferred] + [Layout.grid,.columns,.rows].filter { $0 != preferred } : [preferred]
        for count in stride(from: min(max(1, settings.capacity), min(4, fitWindows.count)), through: 1, by: -1) {
            var candidate = state
            candidate.reconcile(windows: fitWindows, capacity: count, focused: focused)
            // Rebalance complete stacks across four Grid slots before reducing
            // the count. Keep the primary at slot zero, and try existing order first.
            let gridOrders = count == 4 ? [[0,1,2,3],[0,1,3,2],[0,2,1,3],[0,2,3,1],[0,3,1,2],[0,3,2,1]] : [Array(candidate.tiles.indices)]
            func needs(_ arrangement:TileState) -> [CGSize] {
                arrangement.tiles.map { ids in
                    ids.reduce(CGSize.zero) { size,id in
                        let required = minimums[id] ?? .zero
                        return CGSize(width:max(size.width,required.width),height:max(size.height,required.height))
                    }
                }
            }
            for layout in layouts {
                let orders = layout == .grid ? gridOrders : [Array(candidate.tiles.indices)]
                for order in orders {
                    let arranged = candidate.reordered(order)
                    if let frames = fit(box:area.insetBy(dx:gap,dy:gap),needs:needs(arranged),gap:gap,layout:layout) {
                        return FittedLayout(state:arranged,frames:frames,layout:layout,floating:floating)
                    }
                }
            }
            // Decorative space must not force an otherwise fitting window out of the layout.
            for layout in layouts {
                let orders = layout == .grid ? gridOrders : [Array(candidate.tiles.indices)]
                for order in orders {
                    let arranged = candidate.reordered(order), required = needs(arranged)
                    guard fit(box:area,needs:required,gap:0,layout:layout) != nil else { continue }
                    var low = 0, high = Int(floor(gap))
                    while low < high {
                        let middle = (low+high+1)/2, candidateGap = CGFloat(middle)
                        if fit(box:area.insetBy(dx:candidateGap,dy:candidateGap),needs:required,gap:candidateGap,layout:layout) != nil { low = middle }
                        else { high = middle-1 }
                    }
                    let fittedGap = CGFloat(low)
                    if let frames = fit(box:area.insetBy(dx:fittedGap,dy:fittedGap),needs:required,gap:fittedGap,layout:layout) {
                        return FittedLayout(state:arranged,frames:frames,layout:layout,floating:floating)
                    }
                }
            }
        }
        // Every remaining window individually fits the full usable screen, so one stack must fit.
        return FittedLayout(state: TileState(), frames: [], layout: preferred, floating: windows)
    }

    /// Equal shares unless a minimum needs more room. Spare space goes to smaller shares first.
    private static func shares(_ total: CGFloat, _ minimums: [CGFloat]) -> [CGFloat]? {
        guard !minimums.isEmpty, total > 0, minimums.reduce(0,+) <= total + 0.01 else { return nil }
        var result = Array(repeating: CGFloat.zero, count: minimums.count)
        var remaining = total, free = Array(minimums.indices)
        while !free.isEmpty {
            let equal = remaining / CGFloat(free.count)
            let constrained = free.filter { minimums[$0] > equal }
            if constrained.isEmpty { for index in free { result[index] = equal }; break }
            for index in constrained { result[index] = minimums[index]; remaining -= result[index] }
            free.removeAll { constrained.contains($0) }
        }
        return result
    }
    private static func fit(box: CGRect, needs: [CGSize], gap: CGFloat, layout: Layout) -> [CGRect]? {
        let n = needs.count
        guard n > 0 else { return [] }
        if n == 1 {
            guard needs[0].width <= box.width + 0.01, needs[0].height <= box.height + 0.01 else { return nil }
            return [box]
        }
        if layout == .rows {
            guard needs.allSatisfy({ $0.width <= box.width + 0.01 }),
                  let heights = shares(box.height - gap * CGFloat(n-1), needs.map(\.height)) else { return nil }
            var y = box.minY
            return heights.map { height in defer { y += height + gap }; return CGRect(x: box.minX, y: y, width: box.width, height: height) }
        }
        if layout == .columns {
            guard needs.allSatisfy({ $0.height <= box.height + 0.01 }),
                  let widths = shares(box.width - gap * CGFloat(n-1), needs.map(\.width)) else { return nil }
            var x = box.minX
            return widths.map { width in defer { x += width + gap }; return CGRect(x: x, y: box.minY, width: width, height: box.height) }
        }
        // Grid keeps the primary at top-left and the existing clockwise slot order.
        let left = n == 4 ? [0,3] : [0], right = n == 2 ? [1] : [1,2]
        guard let widths = shares(box.width-gap, [left.map{needs[$0].width}.max() ?? 0, right.map{needs[$0].width}.max() ?? 0]) else { return nil }
        var frames = Array(repeating: CGRect.zero, count: n)
        for (column, indices) in [left,right].enumerated() {
            guard let heights = shares(box.height-gap*CGFloat(indices.count-1),indices.map{needs[$0].height}) else { return nil }
            var y = box.minY
            for (row,index) in indices.enumerated() {
                frames[index] = CGRect(x: box.minX + (column == 0 ? 0 : widths[0]+gap), y: y, width: widths[column], height: heights[row])
                y += heights[row] + gap
            }
        }
        return frames
    }
}

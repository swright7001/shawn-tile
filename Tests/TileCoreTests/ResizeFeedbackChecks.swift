import Foundation
import CoreGraphics
import TileCore

func runResizeFeedbackChecks() {
    let target = CGSize(width: 500, height: 350)
    // A slow app is still shrinking at the second observation. Its intermediate
    // geometry must not poison the planner with a fictitious minimum.
    XCTAssertEqual(ResizeFeedback.minimum(prior: .zero, target: target,
        first: CGSize(width: 1200, height: 800), confirmed: CGSize(width: 900, height: 600), written: true), .zero)
    // A client can acknowledge AXSize but ignore one axis. Stable is not
    // sufficient evidence when that axis never changed from the starting size.
    let start = CGSize(width: 1400, height: 800)
    let ignoredWidth = CGSize(width: 1400, height: 350)
    XCTAssertEqual(ResizeFeedback.minimum(prior: .zero, target: target,
        first: ignoredWidth, confirmed: ignoredWidth, written: true, before: start), .zero)
    XCTAssertEqual(ResizeFeedback.minimum(prior: start, target: target,
        first: target, confirmed: target, written: true, before: target), target)
    XCTAssertEqual(ResizeFeedback.minimum(prior:.zero,target:target,first:start,
        confirmed:start,written:true,before:start,probe:CGSize(width:1432,height:832)),start)
    let ignored = Dictionary(uniqueKeysWithValues: ["a","b","c","d"].map {
        ($0, ResizeFeedback.minimum(prior: .zero,target: target,first: start,
            confirmed: start,written: true,before: start))
    })
    XCTAssertEqual(AdaptiveLayout.plan(in: CGRect(x:0,y:0,width:1200,height:800),
        windows:["a","b","c","d"],state:TileState(),minimums:ignored,
        settings:DisplaySettings(layout:.grid,capacity:4,gap:0),focused:nil).state.tiles.count,4)
    let minimum = CGSize(width: 650, height: 450)
    XCTAssertEqual(ResizeFeedback.minimum(prior: .zero, target: target,
        first: minimum, confirmed: minimum, written: true), minimum)
    XCTAssertEqual(ResizeFeedback.minimum(prior: minimum, target: target,
        first: target, confirmed: target, written: true), target)
    for missing in [true, false] {
        XCTAssertEqual(ResizeFeedback.minimum(prior: minimum, target: target,
            first: missing ? nil : minimum, confirmed: missing ? minimum : nil, written: true), minimum)
    }
    XCTAssertEqual(ResizeFeedback.minimum(prior: .zero, target: target,
        first: minimum, confirmed: minimum, written: false), .zero)
    // Position-only failures are reported separately by the adapter; dimensions
    // that actually fit must never be enlarged by the learner.
    XCTAssertEqual(ResizeFeedback.minimum(prior: .zero, target: target,
        first: target, confirmed: target, written: true), .zero)
    // Feed four delayed clients through the same planner used by the app.
    let ids = ["a", "b", "c", "d"]
    let area = CGRect(x: 0, y: 0, width: 1200, height: 800)
    let settings = DisplaySettings(layout: .grid, capacity: 4, gap: 0)
    let requests = Geometry.frames(in: area, count: 4, settings: settings)
    let observed = Dictionary(uniqueKeysWithValues: ids.enumerated().map { index, id in
        (id, ResizeFeedback.minimum(prior: .zero, target: requests[index].size,
            first: area.size, confirmed: CGSize(width: 900, height: 600), written: true))
    })
    let plan = AdaptiveLayout.plan(in: area, windows: ids, state: TileState(),
        minimums: observed, settings: settings, focused: nil)
    XCTAssertEqual(plan.state.tiles.count, 4)
    let settled = Dictionary(uniqueKeysWithValues: ids.enumerated().map { index, id in
        (id, ResizeFeedback.minimum(prior: .zero, target: requests[index].size,
            first: requests[index].size, confirmed: requests[index].size, written: true))
    })
    XCTAssertEqual(AdaptiveLayout.plan(in: area, windows: ids, state: plan.state,
        minimums: settled, settings: settings, focused: nil).state.tiles.count, 4)
    let frame = requests[0]
    XCTAssertTrue(ResizeFeedback.matches(frame, frame))
    XCTAssertTrue(!ResizeFeedback.matches(frame.offsetBy(dx: 50, dy: 0), frame))
    XCTAssertTrue(!ResizeFeedback.matches(frame.insetBy(dx: 20, dy: 20), frame))
    XCTAssertEqual(ResizeFeedback.minimum(prior: minimum, target: target,
        first: .zero, confirmed: .zero, written: true), minimum)
}

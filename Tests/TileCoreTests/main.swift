import Foundation
private var checks = 0
func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) { checks += 1; if !value { fatalError("Check failed at \(file):\(line)") } }
func XCTAssertEqual<T: Equatable>(_ a: T,_ b: T, file: StaticString = #file,line: UInt = #line) { checks += 1; if a != b { fatalError("Expected \(b), got \(a) at \(file):\(line)") } }
func XCTAssertGreaterThan<T: Comparable>(_ a:T,_ b:T,file:StaticString = #file,line:UInt = #line) { checks += 1; if a <= b { fatalError("Expected \(a) > \(b) at \(file):\(line)") } }
import CoreGraphics
import TileCore
final class LayoutTests {
    func testEveryLayoutStaysInsideAndDoesNotOverlap() {
        for area in [CGRect(x: 0,y: 25,width: 1512,height: 900), CGRect(x: -1920,y: -300,width: 1920,height: 1080), CGRect(x: 200,y: -1200,width: 900,height: 1600)] {
            for layout in Layout.allCases { for count in 1...4 { for gap in [0.0, 10, 32] {
                let frames = Geometry.frames(in: area, count: count, settings: .init(layout: layout, gap: gap))
                XCTAssertEqual(frames.count, count)
                for (i, f) in frames.enumerated() {
                    XCTAssertGreaterThan(f.width, 0); XCTAssertGreaterThan(f.height, 0)
                    XCTAssertTrue(area.insetBy(dx: -1,dy: -1).contains(f))
                    for b in frames.dropFirst(i+1) {
                        let intersection = f.intersection(b)
                        XCTAssertTrue(intersection.isNull || intersection.width <= 1 || intersection.height <= 1)
                    }
                }
            } } }
        }
    }
    func testGridGoldenFrames() {
        let f = Geometry.frames(in: CGRect(x: 0,y: 0,width: 1000,height: 800),count: 3,settings: .init(gap: 0))
        XCTAssertEqual(f, [CGRect(x:0,y:0,width:500,height:800),CGRect(x:500,y:0,width:500,height:400),CGRect(x:500,y:400,width:500,height:400)])
        XCTAssertEqual(Geometry.frames(in: .zero,count:4,settings:.init()), [])
    }
    func testCoordinateConversionAndScreenSelection() {
        XCTAssertEqual(Geometry.axRect(fromCocoa: CGRect(x:-100,y:900,width:800,height:600),primaryHeight:900), CGRect(x:-100,y:-600,width:800,height:600))
        XCTAssertEqual(Geometry.bestScreen(for:CGRect(x:-500,y:0,width:300,height:300), screens:[CGRect(x:0,y:0,width:1000,height:800),CGRect(x:-1000,y:0,width:1000,height:800)]),1)
    }
    func testOverflowUsesFocusedTileAndClosingReflows() {
        var s = TileState(); s.reconcile(windows:["a","b","c"],capacity:3,focused:nil)
        s.reconcile(windows:["a","b","c","d"],capacity:3,focused:"b")
        XCTAssertEqual(s.tiles, [["a"],["b","d"],["c"]]); XCTAssertEqual(s.next(in:"b"),"d")
        s.reconcile(windows:["a","c","d"],capacity:3,focused:"d")
        XCTAssertEqual(s.tiles, [["a"],["d"],["c"]])
        s.reconcile(windows:["c","d"],capacity:3,focused:nil)
        XCTAssertEqual(s.tiles, [["d"],["c"]])
    }
    func testCapacityShrinksAndPromotesWithoutDuplicates() {
        var s = TileState(); s.reconcile(windows:["a","b","c","d"],capacity:4,focused:nil)
        s.reconcile(windows:["a","b","c","d"],capacity:2,focused:nil)
        XCTAssertEqual(s.tiles.count,2); XCTAssertEqual(Set(s.tiles.flatMap{$0}),Set(["a","b","c","d"]))
        s.reconcile(windows:["a","b","c","d"],capacity:4,focused:nil)
        XCTAssertEqual(s.tiles.count,4)
        s.swap("a","d"); XCTAssertEqual(s.tiles[0],["d"])
    }
    func testFocusDoesNotChangeOrderAndReconcileIsIdempotent() {
        var s = TileState(); s.reconcile(windows:["a","b","c","d","e"],capacity:3,focused:nil)
        let before = s
        s.reconcile(windows:["a","b","c","d","e"],capacity:3,focused:"a")
        XCTAssertEqual(s,before); XCTAssertEqual(s.next(in:"c",offset:-1),"e")
        s.reconcile(windows:[],capacity:0,focused:nil); XCTAssertEqual(s.tiles,[])
    }
}

let tests = LayoutTests()
tests.testEveryLayoutStaysInsideAndDoesNotOverlap()
tests.testGridGoldenFrames()
tests.testCoordinateConversionAndScreenSelection()
tests.testOverflowUsesFocusedTileAndClosingReflows()
tests.testCapacityShrinksAndPromotesWithoutDuplicates()
tests.testFocusDoesNotChangeOrderAndReconcileIsIdempotent()
print("PASS: 6 scenarios, \(checks) assertions")

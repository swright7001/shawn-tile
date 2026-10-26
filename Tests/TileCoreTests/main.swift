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
    func testAdaptiveSplitsAndAlternateLayout() {
        let area = CGRect(x:0,y:0,width:1600,height:1000)
        let plan = AdaptiveLayout.plan(in:area,windows:["a","b"],state:TileState(),minimums:["a":CGSize(width:1000,height:400),"b":CGSize(width:400,height:300)],settings:.init(gap:10),focused:nil)
        XCTAssertEqual(plan.state.tiles.count,2); XCTAssertTrue(plan.frames[0].width >= 1000)
        XCTAssertTrue(plan.frames[1].width >= 400); XCTAssertTrue(plan.frames[0].maxX+10 <= plan.frames[1].minX+0.01)
        let tall = AdaptiveLayout.plan(in:area,windows:["a","b","c"],state:TileState(),minimums:Dictionary(uniqueKeysWithValues:["a","b","c"].map{($0,CGSize(width:400,height:700))}),settings:.init(gap:10),focused:nil)
        XCTAssertEqual(tall.state.tiles.count,3); XCTAssertEqual(tall.layout,.columns)
        XCTAssertTrue(tall.frames.allSatisfy{$0.height >= 700})
    }
    func testAdaptiveStackingAndRecovery() {
        let area = CGRect(x:-1600,y:-200,width:1600,height:1000)
        let minimums = Dictionary(uniqueKeysWithValues:["a","b","c"].map{($0,CGSize(width:900,height:600))})
        let crowded = AdaptiveLayout.plan(in:area,windows:["a","b","c"],state:TileState(),minimums:minimums,settings:.init(gap:10),focused:"a")
        XCTAssertEqual(crowded.state.tiles.count,1); XCTAssertEqual(crowded.state.tiles[0].count,3)
        let recovered = AdaptiveLayout.plan(in:area,windows:["c","d","e"],state:crowded.state,minimums:minimums,settings:.init(gap:10),focused:nil)
        XCTAssertEqual(recovered.state.tiles.count,3); XCTAssertTrue(recovered.floating.isEmpty)
        XCTAssertEqual(Set(recovered.state.tiles.flatMap{$0}),Set(["c","d","e"]))
    }
    func testOversizedAndFixedMode() {
        let area = CGRect(x:0,y:0,width:1000,height:800)
        let mins = ["a":CGSize(width:1500,height:900)]
        let plan = AdaptiveLayout.plan(in:area,windows:["a","b","c"],state:TileState(),minimums:mins,settings:.init(),focused:nil)
        XCTAssertEqual(plan.floating,["a"]); XCTAssertEqual(plan.state.tiles.count,2)
        let fixed = AdaptiveLayout.plan(in:area,windows:["a","b","c"],state:TileState(),minimums:mins,settings:.init(autoFit:false),focused:nil)
        XCTAssertEqual(fixed.state.tiles.count,3); XCTAssertTrue(fixed.floating.isEmpty)
        let empty = AdaptiveLayout.plan(in:.zero,windows:[],state:TileState(),minimums:[:],settings:.init(),focused:nil)
        XCTAssertTrue(empty.frames.isEmpty)
    }
    func testAdaptivePlansHonorEveryStackMember() {
        let ids = ["a","b","c","d","e","f"]
        for area in [CGRect(x:-1300,y:0,width:1300,height:900),CGRect(x:0,y:-1400,width:900,height:1400)] {
            for layout in Layout.allCases { for cap in 1...4 { for large in [CGSize(width:500,height:300),CGSize(width:750,height:650),CGSize(width:1200,height:900)] {
                let minimums = Dictionary(uniqueKeysWithValues:ids.enumerated().map{($0.element,$0.offset%2 == 0 ? large : CGSize(width:250,height:200))})
                let plan = AdaptiveLayout.plan(in:area,windows:ids,state:TileState(),minimums:minimums,settings:.init(layout:layout,capacity:cap,gap:10),focused:nil)
                XCTAssertEqual(Set(plan.state.tiles.flatMap{$0}+plan.floating),Set(ids))
                XCTAssertEqual(plan.state.tiles.flatMap{$0}.count+plan.floating.count,ids.count)
                XCTAssertTrue(plan.frames.count <= cap)
                for (slot,members) in plan.state.tiles.enumerated() {
                    let frame = plan.frames[slot]
                    XCTAssertTrue(area.contains(frame)); XCTAssertGreaterThan(frame.width,0); XCTAssertGreaterThan(frame.height,0)
                    for id in members { XCTAssertTrue(frame.width+0.01 >= minimums[id]!.width); XCTAssertTrue(frame.height+0.01 >= minimums[id]!.height) }
                    for other in plan.frames.dropFirst(slot+1) { XCTAssertTrue(frame.intersection(other).isNull || frame.intersection(other).isEmpty) }
                }
            } } }
        }
    }
    func testAdaptiveGapsBeforeFloatingOrStacking() {
        let area = CGRect(x:0,y:0,width:1600,height:1000)
        let plan = AdaptiveLayout.plan(in:area,windows:["a","b","c"],state:TileState(),minimums:["a":CGSize(width:500,height:990)],settings:.init(gap:20),focused:nil)
        XCTAssertTrue(plan.floating.isEmpty); XCTAssertEqual(plan.frames.count,3)
        XCTAssertTrue(plan.frames[plan.state.slot(of:"a")!].height >= 990)
        XCTAssertEqual(plan.frames[0].minY,5)
        let fullHeight = AdaptiveLayout.plan(in:area,windows:["a","b"],state:TileState(),minimums:["a":CGSize(width:600,height:1000)],settings:.init(gap:10),focused:nil)
        XCTAssertTrue(fullHeight.floating.isEmpty); XCTAssertEqual(fullHeight.frames.count,2)
        XCTAssertEqual(fullHeight.frames[0].height,1000)
        let tooBig = AdaptiveLayout.plan(in:area,windows:["a","b"],state:TileState(),minimums:["a":CGSize(width:600,height:1001)],settings:.init(gap:0),focused:nil)
        XCTAssertEqual(tooBig.floating,["a"])
    }
    func testLegacyPreferencesMigration() {
        let legacy = Data(#"{"layout":"columns","capacity":2,"gap":8}"#.utf8)
        let config = try! JSONDecoder().decode(DisplaySettings.self,from:legacy)
        XCTAssertTrue(config.autoFit); XCTAssertEqual(config.capacity,2); XCTAssertEqual(config.layout,.columns)
        let encoded = try! JSONEncoder().encode(DisplaySettings(autoFit:false))
        XCTAssertEqual(try! JSONDecoder().decode(DisplaySettings.self,from:encoded).autoFit,false)
    }
    func testShortcutDefaultsAndValidation() {
        let defaults = ShortcutConfiguration()
        XCTAssertEqual(defaults.validationError,nil)
        XCTAssertEqual(ShortcutAction.allCases.count,15)
        XCTAssertEqual(Set(ShortcutAction.allCases.map(\.eventID)).count,15)
        XCTAssertEqual(Set(ShortcutKey.all.map(\.code)).count,ShortcutKey.all.count)
        for action in ShortcutAction.allCases {
            XCTAssertEqual(defaults[action],action.defaultBinding)
            XCTAssertEqual(defaults[action].validationError,nil)
        }
        XCTAssertTrue(ShortcutBinding(keyCode:999,modifiers:ShortcutBinding.control).validationError != nil)
        XCTAssertTrue(ShortcutBinding(keyCode:0,modifiers:ShortcutBinding.shift).validationError != nil)
        XCTAssertTrue(ShortcutBinding(keyCode:0,modifiers:ShortcutBinding.option).validationError != nil)
        XCTAssertTrue(ShortcutBinding(keyCode:0,modifiers:UInt32.max).validationError != nil)
    }
    func testShortcutConflictsAndDisabling() {
        var config = ShortcutConfiguration()
        config[.pause] = config[.focus]
        XCTAssertTrue(config.validationError?.contains("Focus / restore") == true)
        config[.pause] = .disabled; config[.focus] = .disabled
        XCTAssertEqual(config.validationError,nil)
        XCTAssertEqual(config[.pause].label,"Disabled")
        config.bindings.removeValue(forKey:ShortcutAction.swapDown.rawValue)
        XCTAssertTrue(config.validationError != nil)
        config = ShortcutConfiguration(); config.bindings["unknown"] = .disabled
        XCTAssertTrue(config.validationError != nil)
    }
    func testShortcutPreferenceRoundTrip() {
        var config = ShortcutConfiguration()
        config[.pause].modifiers |= ShortcutBinding.shift
        config[.focus] = .disabled
        let data = try! JSONEncoder().encode(config)
        let loaded = try! JSONDecoder().decode(ShortcutConfiguration.self,from:data)
        XCTAssertEqual(loaded,config); XCTAssertEqual(loaded.validationError,nil)
        XCTAssertEqual(loaded[.pause].label,"⌃⌥⇧ P")
        XCTAssertEqual(loaded[.focus],.disabled)
    }
    func testScreenSharingShortcuts() {
        let config = ShortcutConfiguration.screenSharing
        XCTAssertEqual(config.validationError,nil)
        XCTAssertEqual(config[.pause].label,"⌃⇧⌘ P")
        for action in ShortcutAction.allCases {
            XCTAssertEqual(config[action].keyCode,action.defaultBinding.keyCode)
            XCTAssertEqual(config[action].modifiers,ShortcutBinding.control | ShortcutBinding.shift | ShortcutBinding.command)
        }
    }

}

let tests = LayoutTests()
tests.testEveryLayoutStaysInsideAndDoesNotOverlap()
tests.testGridGoldenFrames()
tests.testCoordinateConversionAndScreenSelection()
tests.testOverflowUsesFocusedTileAndClosingReflows()
tests.testCapacityShrinksAndPromotesWithoutDuplicates()
tests.testFocusDoesNotChangeOrderAndReconcileIsIdempotent()
tests.testAdaptiveSplitsAndAlternateLayout()
tests.testAdaptiveStackingAndRecovery()
tests.testOversizedAndFixedMode()
tests.testAdaptivePlansHonorEveryStackMember()
tests.testLegacyPreferencesMigration()
tests.testAdaptiveGapsBeforeFloatingOrStacking()
tests.testShortcutDefaultsAndValidation()
tests.testShortcutConflictsAndDisabling()
tests.testShortcutPreferenceRoundTrip()
tests.testScreenSharingShortcuts()
runExplicitLayoutChecks()
runUpdateChecks()
print("PASS: layout, shortcuts, update validation and archive checks; \(checks) assertions")

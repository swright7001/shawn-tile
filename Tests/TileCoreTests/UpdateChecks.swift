import Foundation
import CryptoKit
import CoreGraphics
import TileCore

func expectFailure(_ action:() throws -> Void) {
    var failed = false
    do { try action() } catch { failed = true }
    XCTAssertTrue(failed)
}
func releaseFixture(_ change:(inout [String:Any])->Void = {_ in}) throws -> Data {
    var release:[String:Any] = ["tag_name":"v0.5.0","html_url":"https://github.com/swright7001/shawn-tile/releases/tag/v0.5.0","name":"New features","body":"Grid and Rows stay selected.\n\nUpdate from the app.","draft":false,"prerelease":false,"assets":[["name":"ShawnTile-0.5.0-universal.zip","browser_download_url":"https://github.com/swright7001/shawn-tile/releases/download/v0.5.0/ShawnTile-0.5.0-universal.zip","digest":"sha256:"+String(repeating:"a",count:64),"size":100,"state":"uploaded"]]]
    change(&release); return try JSONSerialization.data(withJSONObject:release)
}
func zipFixture(name:String,mode:Int = 0x81a4) -> Data {
    var bytes = Data()
    func number(_ n:Int,_ count:Int) { for i in 0..<count { bytes.append(UInt8((n >> (i*8)) & 255)) } }
    let text = Data(name.utf8)
    number(0x04034b50,4); number(20,2); number(0,2); number(0,2); number(0,2); number(0,2)
    number(0,4); number(0,4); number(0,4); number(text.count,2); number(0,2); bytes.append(text)
    let offset = bytes.count
    number(0x02014b50,4); number(0x0314,2); number(20,2); number(0,2); number(0,2); number(0,2); number(0,2)
    number(0,4); number(0,4); number(0,4); number(text.count,2); number(0,2); number(0,2); number(0,2); number(0,2); number(mode << 16,4); number(0,4); bytes.append(text)
    let length = bytes.count-offset
    number(0x06054b50,4); number(0,2); number(0,2); number(1,2); number(1,2); number(length,4); number(offset,4); number(0,2)
    return bytes
}
func runUpdateChecks() {
    XCTAssertTrue(AppVersion("0.10.0")! > AppVersion("0.9.9")!)
    XCTAssertEqual(AppVersion("v1.2.3"),AppVersion("1.2.3"))
    for invalid in ["", "1.2", "1.2.3-beta", "1.2.3.4", "01.2.3", "1.-2.3", "1.2.99999999999999999999", "1.2.３"] { XCTAssertEqual(AppVersion(invalid),nil) }
    let update = try! ReleaseFeed.parse(releaseFixture(),current:"0.4.1")!
    XCTAssertEqual(update.version,"0.5.0"); XCTAssertEqual(update.summary,"Grid and Rows stay selected.")
    XCTAssertEqual(try! ReleaseFeed.parse(releaseFixture(),current:"0.5.0"),nil)
    XCTAssertEqual(try! ReleaseFeed.parse(releaseFixture(),current:"1.0.0"),nil)
    for field in ["draft","prerelease"] { expectFailure { _ = try ReleaseFeed.parse(releaseFixture{$0[field]=true},current:"0.4.1") } }
    expectFailure { _ = try ReleaseFeed.parse(releaseFixture{$0["tag_name"]="v0.5.0-beta"},current:"0.4.1") }
    expectFailure { _ = try ReleaseFeed.parse(releaseFixture{$0["html_url"]="https://example.com/release"},current:"0.4.1") }
    for mutation in 0..<6 {
        expectFailure {
            let data = try releaseFixture { release in
                var assets = release["assets"] as! [[String:Any]]
                switch mutation {
                case 0: assets[0]["digest"] = NSNull()
                case 1: assets[0]["size"] = ReleaseFeed.maximumArchiveSize+1
                case 2: assets[0]["browser_download_url"] = "https://github.com/attacker/shawn-tile/releases/download/v0.5.0/ShawnTile-0.5.0-universal.zip"
                case 3: assets[0]["state"] = "new"
                case 4: assets.append(assets[0])
                default: assets[0]["digest"] = "sha256:wrong"
                }
                release["assets"] = assets
            }
            _ = try ReleaseFeed.parse(data,current:"0.4.1")
        }
    }
    XCTAssertTrue(ReleaseFeed.trustedURL(ReleaseFeed.latest))
    XCTAssertTrue(ReleaseFeed.trustedURL(URL(string:"https://release-assets.githubusercontent.com/file?token=example")!,download:true))
    for text in ["http://github.com/a","https://github.com.evil.test/a","https://user@github.com/a","https://github.com:444/a","file:///tmp/app.zip"] {
        XCTAssertTrue(!ReleaseFeed.trustedURL(URL(string:text)!,download:true))
    }
    let content = Data("verified download".utf8), file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! content.write(to:file); defer { try? FileManager.default.removeItem(at:file) }
    let digest = SHA256.hash(data:content).map{String(format:"%02x",$0)}.joined()
    let verified = try! ReleaseFeed.parse(releaseFixture { release in
        var assets = release["assets"] as! [[String:Any]]; assets[0]["size"] = content.count; assets[0]["digest"] = "sha256:"+digest; release["assets"] = assets
    },current:"0.4.1")!
    try! ReleaseFeed.verifyArchive(file,update:verified)
    try! Data(repeating:0,count:content.count).write(to:file)
    expectFailure { try ReleaseFeed.verifyArchive(file,update:verified) }
    try! Data().write(to:file); expectFailure { try ReleaseFeed.verifyArchive(file,update:verified) }
    try! UpdateArchive.validate(zipFixture(name:"Shawn Tile.app/Contents/Info.plist"))
    for name in ["../outside", "/absolute", "Shawn Tile.app/../../outside", "Shawn Tile.app/a/../outside", "Shawn Tile.app/a\\outside", "Other.app/Contents/Info.plist", "Shawn Tile.app/a\nfile", "Shawn Tile.app/./file"] {
        expectFailure { try UpdateArchive.validate(zipFixture(name:name)) }
    }
    expectFailure { try UpdateArchive.validate(zipFixture(name:"Shawn Tile.app/link",mode:0xa1ff)) }
    let zip = zipFixture(name:"Shawn Tile.app/file")
    for size in [0,10,21,zip.count-1] { expectFailure { try UpdateArchive.validate(Data(zip.prefix(size))) } }
}
func runExplicitLayoutChecks() {
    let windows = ["a","b","c","d"], tall = Dictionary(uniqueKeysWithValues:windows.map{($0,CGSize(width:300,height:700))})
    let area = CGRect(x:0,y:0,width:1600,height:1000)
    let auto = AdaptiveLayout.plan(in:area,windows:windows,state:TileState(),minimums:tall,settings:.init(layout:.automatic,capacity:4),focused:nil)
    XCTAssertEqual(auto.layout,.columns); XCTAssertEqual(auto.state.tiles.count,4)
    let grid = AdaptiveLayout.plan(in:area,windows:windows,state:TileState(),minimums:tall,settings:.init(layout:.grid,capacity:4),focused:nil)
    XCTAssertEqual(grid.layout,.grid); XCTAssertEqual(grid.state.tiles.count,2)
    let rows = AdaptiveLayout.plan(in:area,windows:windows,state:TileState(),minimums:tall,settings:.init(layout:.rows,capacity:4),focused:nil)
    XCTAssertEqual(rows.layout,.rows); XCTAssertEqual(rows.state.tiles.count,1)
    for orientation in [area,CGRect(x:-800,y:0,width:800,height:1400)] {
        for layout in [Layout.grid,.rows,.columns] {
            let plan = AdaptiveLayout.plan(in:orientation,windows:windows,state:TileState(),minimums:[:],settings:.init(layout:layout,capacity:4),focused:nil)
            XCTAssertEqual(plan.layout,layout); XCTAssertEqual(plan.state.tiles.count,4)
            let frames = Geometry.frames(in:orientation,count:4,settings:.init(layout:layout,capacity:4,autoFit:false))
            if layout == .columns { XCTAssertTrue(frames.allSatisfy{$0.height == frames[0].height}); XCTAssertEqual(Set(frames.map(\.minY)).count,1) }
            if layout == .rows { XCTAssertTrue(frames.allSatisfy{$0.width == frames[0].width}); XCTAssertEqual(Set(frames.map(\.minX)).count,1) }
            if layout == .grid { XCTAssertEqual(Set(frames.map(\.minX)).count,2); XCTAssertEqual(Set(frames.map(\.minY)).count,2) }
        }
    }
    var state = TileState(); state.reconcile(windows:windows,capacity:4,focused:nil)
    let unbalanced = ["b":CGSize(width:300,height:650),"c":CGSize(width:300,height:650)]
    let balanced = AdaptiveLayout.plan(in:area,windows:windows,state:state,minimums:unbalanced,settings:.init(layout:.grid,capacity:4),focused:nil)
    XCTAssertEqual(balanced.state.tiles.count,4); XCTAssertEqual(balanced.state.tiles[0],["a"])
    XCTAssertEqual(balanced.layout,.grid)
    for (slot,members) in balanced.state.tiles.enumerated() {
        for id in members { XCTAssertTrue(balanced.frames[slot].height >= (unbalanced[id]?.height ?? 0)) }
    }
    let legacy = try! JSONDecoder().decode(DisplaySettings.self,from:Data(#"{"layout":"rows","capacity":4,"gap":10,"autoFit":true}"#.utf8))
    XCTAssertEqual(legacy.layout,.rows)
}

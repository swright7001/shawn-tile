import Foundation
import CryptoKit
import TileCore

func runUpdaterChecks() {
    setbuf(stdout,nil)
    guard CommandLine.arguments.count == 5 else { print("Usage: --updater-test archive.zip installed.app helper.sh"); exit(2) }
    let fm = FileManager.default, archive = URL(fileURLWithPath:CommandLine.arguments[2])
    let source = URL(fileURLWithPath:CommandLine.arguments[3],isDirectory:true), helper = CommandLine.arguments[4]
    let root = URL(fileURLWithPath:fm.currentDirectoryPath,isDirectory:true).appendingPathComponent(".build/updater-checks-"+UUID().uuidString,isDirectory:true)
    var count = 0, failures = 0
    func check(_ value:Bool,_ label:String) { count += 1; if !value { failures += 1 }; print("\(value ? "PASS" : "FAIL"): \(label)") }
    func fails(_ label:String,_ action:() throws -> Void) { do { try action(); check(false,label) } catch { check(true,label) } }
    func inode(_ url:URL) throws -> UInt64 { (try fm.attributesOfItem(atPath:url.path)[.systemFileNumber] as! NSNumber).uint64Value }
    do {
        try fm.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? fm.removeItem(at:root) }
        let info = try PropertyListSerialization.propertyList(from:Data(contentsOf:source.appendingPathComponent("Contents/Info.plist")),format:nil) as! [String:Any]
        let version = info["CFBundleShortVersionString"] as! String
        let sourceIsAdhoc = try UpdateInstaller.run("/usr/bin/codesign",["-d","-v",source.path]).contains("Signature=adhoc")
        let bytes = try Data(contentsOf:archive), digest = SHA256.hash(data:bytes).map{String(format:"%02x",$0)}.joined()
        let name = "ShawnTile-\(version)-universal.zip"
        let metadata:[String:Any] = ["tag_name":"v"+version,"html_url":"https://github.com/swright7001/shawn-tile/releases/tag/v"+version,"draft":false,"prerelease":false,"name":"Installer fixture","body":"Disposable installer checks","assets":[["name":name,"browser_download_url":"https://github.com/swright7001/shawn-tile/releases/download/v"+version+"/"+name,"digest":"sha256:"+digest,"size":bytes.count,"state":"uploaded"]]]
        let update = try ReleaseFeed.parse(JSONSerialization.data(withJSONObject:metadata),current:"0.0.0")!
        try UpdateArchive.validate(bytes); check(true,"real release ZIP passes safe directory validation")
        let publicFolder = root.appendingPathComponent("public-source",isDirectory:true)
        try fm.createDirectory(at:publicFolder,withIntermediateDirectories:false)
        _ = try UpdateInstaller.run("/usr/bin/ditto",["-x","-k",archive.path,publicFolder.path])
        for (fail,publicBuild) in [(false,false),(true,false),(false,true)] {
            let folder = root.appendingPathComponent(publicBuild ? "public-success" : (fail ? "rollback" : "success"),isDirectory:true)
            try fm.createDirectory(at:folder,withIntermediateDirectories:false)
            let current = folder.appendingPathComponent("Shawn Tile.app",isDirectory:true)
            _ = try UpdateInstaller.run("/usr/bin/ditto",[(publicBuild ? publicFolder.appendingPathComponent("Shawn Tile.app") : source).path,current.path])
            let before = try inode(current)
            let work = folder.appendingPathComponent("work",isDirectory:true); try fm.createDirectory(at:work,withIntermediateDirectories:false)
            let stage = try UpdateInstaller.prepare(archive:archive,update:update,current:current,work:work,signingConfiguration:(publicBuild || sourceIsAdhoc) ? root.appendingPathComponent("no-local-identity.json") : nil)
            let preparedID = try inode(current)
            check(fm.fileExists(atPath:current.path) && preparedID == before,"preparation leaves current app unchanged")
            _ = try UpdateInstaller.run("/usr/bin/codesign",["--verify","--deep","--strict",stage.appendingPathComponent("Shawn Tile.app").path])
            check(true,publicBuild ? "public ad hoc update verifies without a local signing setup" : "prepared update strictly verifies in its expected signing mode")
            let process = Process(), output = Pipe()
            process.executableURL = URL(fileURLWithPath:"/bin/bash"); process.arguments = [helper,String(Int32.max),stage.path,current.path]
            process.environment = ProcessInfo.processInfo.environment.merging(["TILE_UPDATE_TESTING":"1","TILE_UPDATE_TEST_FAIL":fail ? "1" : "0"],uniquingKeysWith:{$1})
            process.standardOutput = output; process.standardError = output
            try process.run(); _ = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
            try UpdateInstaller.validate(current,version:version)
            let backups = try fm.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil).filter{$0.lastPathComponent.contains(".app.backup-")}
            if fail {
                check(process.terminationStatus == 68,"injected replacement failure is reported")
                check(try inode(current) == before,"failure restores the exact previous app directory")
                check(backups.isEmpty,"rollback restores previous app to its original path")
            } else {
                check(process.terminationStatus == 0,"helper completes successful replacement")
                check(try inode(current) != before,"new app replaces current app directory")
                check(backups.count == 1,"successful update keeps the previous app backup")
            }
        }
        let rejection = root.appendingPathComponent("rejected",isDirectory:true)
        try fm.createDirectory(at:rejection,withIntermediateDirectories:false)
        let current = rejection.appendingPathComponent("Shawn Tile.app",isDirectory:true)
        _ = try UpdateInstaller.run("/usr/bin/ditto",[source.path,current.path]); let before = try inode(current)
        let broken = rejection.appendingPathComponent("broken.zip"); try (bytes+Data([0])).write(to:broken)
        fails("wrong checksum/size is rejected before replacement") {
            _ = try UpdateInstaller.prepare(archive:broken,update:update,current:current,work:rejection)
        }
        fails("wrong app version is rejected") { try UpdateInstaller.validate(current,version:"999.0.0") }
        let badConfig = rejection.appendingPathComponent("identity.json")
        try JSONSerialization.data(withJSONObject:["identity":String(repeating:"0",count:40),"bundle_identifier":UpdateInstaller.bundleID]).write(to:badConfig)
        let work = rejection.appendingPathComponent("work",isDirectory:true); try fm.createDirectory(at:work,withIntermediateDirectories:false)
        fails("mismatched configured signer fails without ad hoc fallback") {
            _ = try UpdateInstaller.prepare(archive:archive,update:update,current:current,work:work,signingConfiguration:badConfig)
        }
        check(try inode(current) == before,"every rejected preparation leaves installed app intact")
        let cancellation = UpdateCancellation(); cancellation.cancel()
        fails("cancelled preparation cannot run") {
            _ = try UpdateInstaller.prepare(archive:archive,update:update,current:current,work:work,cancellation:cancellation)
        }
        let running = UpdateCancellation(), start = Date()
        DispatchQueue.global().asyncAfter(deadline:.now()+0.2) { running.cancel() }
        fails("cancellation stops an active preparation process") { _ = try UpdateInstaller.run("/bin/sleep",["10"],cancellation:running) }
        check(Date().timeIntervalSince(start)<3,"cancellation does not wait for a blocked process")
    } catch { check(false,"installer check error: \(error.localizedDescription)") }
    print("UPDATER: \(count) checks, \(failures) failures; disposable copies only")
    exit(failures == 0 ? 0 : 1)
}

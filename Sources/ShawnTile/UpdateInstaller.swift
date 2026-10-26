import Foundation
import TileCore

/// Runs only after the user presses Update. Every validation precedes replacement.
enum UpdateInstaller {
    static let bundleID = "com.shawnwright.ShawnTile"
    static func run(_ command:String,_ arguments:[String],cancellation:UpdateCancellation? = nil) throws -> String {
        try cancellation?.check()
        let task = Process(), output = Pipe()
        task.executableURL = URL(fileURLWithPath:command); task.arguments = arguments
        task.standardOutput = output; task.standardError = output
        try task.run(); cancellation?.attach(task)
        defer { cancellation?.detach() }
        let data = output.fileHandleForReading.readDataToEndOfFile(); task.waitUntilExit()
        try cancellation?.check()
        let text = String(data:data,encoding:.utf8) ?? ""
        guard task.terminationStatus == 0 else { throw UpdateError.invalid(text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "The update could not be prepared. The installed app was kept." : String(text.prefix(1200))) }
        return text
    }
    static func validate(_ app:URL,version:String) throws {
        let info = try PropertyListSerialization.propertyList(from:Data(contentsOf:app.appendingPathComponent("Contents/Info.plist")),format:nil) as? [String:Any] ?? [:]
        guard info["CFBundleIdentifier"] as? String == bundleID,
              info["CFBundleExecutable"] as? String == "ShawnTile",
              info["CFBundleShortVersionString"] as? String == version else { throw UpdateError.invalid("The downloaded app has an unexpected identity or version.") }
        if let minimum = info["LSMinimumSystemVersion"] as? String {
            let raw = minimum.split(separator:".",omittingEmptySubsequences:false)
            let fields = raw.compactMap{Int($0)}
            guard (1...3).contains(raw.count), fields.count == raw.count, fields.allSatisfy({$0>=0 && $0<=999999}) else { throw UpdateError.invalid("The update has an invalid macOS requirement.") }
            let os = ProcessInfo.processInfo.operatingSystemVersion
            guard ![os.majorVersion,os.minorVersion,os.patchVersion].lexicographicallyPrecedes(Array((fields + [0,0,0]).prefix(3))) else { throw UpdateError.invalid("This update needs a newer version of macOS.") }
        }
        do { _ = try run("/usr/bin/codesign",["--verify","--deep","--strict",app.path]) }
        catch { throw UpdateError.invalid("The downloaded app failed its signature check. Your installed app was kept.") }
    }
    static func prepare(archive:URL,update:ReleaseUpdate,current:URL,work:URL,signingConfiguration:URL? = nil,cancellation:UpdateCancellation? = nil) throws -> URL {
        try cancellation?.check()
        func run(_ command:String,_ arguments:[String]) throws -> String { try Self.run(command,arguments,cancellation:cancellation) }
        try ReleaseFeed.verifyArchive(archive,update:update)
        let fm = FileManager.default
        let parent = current.deletingLastPathComponent().resolvingSymlinksInPath()
        guard current.pathExtension == "app", current.resolvingSymlinksInPath() == current.standardizedFileURL,
              fm.isWritableFile(atPath:parent.path), !current.path.hasPrefix("/Volumes/"), !current.path.contains("/AppTranslocation/") else {
            throw UpdateError.invalid("Move Shawn Tile to your Applications folder before updating. Use ~/Applications if your account cannot replace apps in /Applications.")
        }
        let extracted = work.appendingPathComponent("extracted",isDirectory:true)
        try fm.createDirectory(at:extracted,withIntermediateDirectories:false)
        try UpdateArchive.validate(Data(contentsOf:archive,options:.mappedIfSafe))
        _ = try run("/usr/bin/ditto",["-x","-k",archive.path,extracted.path])
        let candidate = extracted.appendingPathComponent("Shawn Tile.app",isDirectory:true)
        let enumerator = fm.enumerator(at:candidate,includingPropertiesForKeys:[.isSymbolicLinkKey])
        while let item = enumerator?.nextObject() as? URL {
            if try item.resourceValues(forKeys:[.isSymbolicLinkKey]).isSymbolicLink == true {
                guard item.resolvingSymlinksInPath().path.hasPrefix(candidate.path+"/") else { throw UpdateError.invalid("The update contains a link outside the app.") }
            }
        }
        try validate(candidate,version:update.version)
        let config = signingConfiguration ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Shawn Tile/Signing/identity.json")
        let oldOutput = try run("/usr/bin/codesign",["-d","-r-",current.path])
        guard let oldRequirement = oldOutput.components(separatedBy:.newlines).first(where:{$0.hasPrefix("designated =>") || $0.hasPrefix("# designated =>")}) else {
            throw UpdateError.invalid("The installed app's signing identity could not be confirmed.")
        }
        if fm.fileExists(atPath:config.path) {
            let data = try JSONSerialization.jsonObject(with:Data(contentsOf:config)) as? [String:Any]
            guard let identity = data?["identity"] as? String, identity.count == 40, identity.allSatisfy({$0.isHexDigit && $0.isASCII}),
                  data?["bundle_identifier"] as? String == bundleID else { throw UpdateError.invalid("Your local signing configuration is invalid. The installed app was kept.") }
            let requirement = "identifier \"\(bundleID)\" and certificate leaf = H\"\(identity)\""
            _ = try run("/usr/bin/codesign",["--verify","--deep","--strict","--test-requirement","="+requirement,current.path])
            do {
                _ = try run("/usr/bin/codesign",["--force","--sign",identity,"--timestamp=none","--identifier",bundleID,"--requirements","=designated => "+requirement,candidate.path])
            } catch {
                try cancellation?.check()
                throw UpdateError.invalid("Your local signing key could not be used. The installed app was kept. Approve the macOS signing prompt or check your local signing setup.")
            }
            _ = try run("/usr/bin/codesign",["--verify","--deep","--strict","--test-requirement","="+requirement,candidate.path])
        } else if oldRequirement.contains("certificate") || oldRequirement.contains("anchor") {
            throw UpdateError.invalid("This copy uses a signing identity that is not configured for local updates. Configure local signing before replacing it.")
        }
        // Stage on the same volume so the helper can rename atomically after exit.
        let stage = parent.appendingPathComponent(".shawn-tile-update-"+UUID().uuidString,isDirectory:true)
        try fm.createDirectory(at:stage,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
        do {
            _ = try run("/usr/bin/ditto",[candidate.path,stage.appendingPathComponent("Shawn Tile.app").path])
            try validate(stage.appendingPathComponent("Shawn Tile.app"),version:update.version)
            return stage
        } catch { try? fm.removeItem(at:stage); throw error }
    }
}

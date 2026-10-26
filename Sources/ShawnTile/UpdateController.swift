import AppKit
import Combine
import TileCore

private final class ReleaseRequest: NSObject, URLSessionDataDelegate {
    private let maximum:Int, download:Bool
    private var content = Data(), redirects = 0
    private var continuation:CheckedContinuation<Data,Error>?
    private var session:URLSession?, task:URLSessionDataTask?
    private let lock = NSLock()
    private var cancelled = false
    init(maximum:Int,download:Bool) { self.maximum = maximum; self.download = download }
    func load(_ url:URL) async throws -> Data {
        try await withTaskCancellationHandler(operation:{
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let config = URLSessionConfiguration.ephemeral
                config.httpCookieStorage = nil; config.urlCredentialStorage = nil; config.urlCache = nil
                config.timeoutIntervalForRequest = 30; config.timeoutIntervalForResource = 180
                let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
                let session = URLSession(configuration:config,delegate:self,delegateQueue:queue); self.session = session
                var request = URLRequest(url:url); request.cachePolicy = .reloadIgnoringLocalCacheData
                request.setValue("ShawnTile-Updater",forHTTPHeaderField:"User-Agent")
                request.setValue(download ? "application/octet-stream" : "application/vnd.github+json",forHTTPHeaderField:"Accept")
                let task = session.dataTask(with:request)
                lock.lock(); self.task = task; let stop = cancelled; lock.unlock()
                task.resume(); if stop { task.cancel() }
            }
        },onCancel:{self.cancel()})
    }
    func cancel() { lock.lock(); cancelled = true; let task = task; lock.unlock(); task?.cancel() }
    private func finish(_ result:Result<Data,Error>) {
        guard let continuation else { return }; self.continuation = nil
        continuation.resume(with:result); session?.finishTasksAndInvalidate(); session = nil
    }
    func urlSession(_ session:URLSession,dataTask:URLSessionDataTask,didReceive response:URLResponse,completionHandler:@escaping (URLSession.ResponseDisposition)->Void) {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let url = response.url, ReleaseFeed.trustedURL(url,download:download),
              response.expectedContentLength <= maximum else {
            completionHandler(.cancel); finish(.failure(UpdateError.invalid("GitHub could not provide this update. Please try again later."))); return
        }
        completionHandler(.allow)
    }
    func urlSession(_ session:URLSession,dataTask:URLSessionDataTask,didReceive data:Data) {
        guard content.count+data.count <= maximum else {
            dataTask.cancel(); finish(.failure(UpdateError.invalid("The update response was larger than expected."))); return
        }
        content.append(data)
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping (URLRequest?)->Void) {
        redirects += 1
        guard redirects <= 5, let url = request.url, ReleaseFeed.trustedURL(url,download:download) else {
            completionHandler(nil); finish(.failure(UpdateError.invalid("The update redirected to an unexpected source."))); return
        }
        completionHandler(request)
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,didCompleteWithError error:Error?) {
        finish(error.map{.failure($0)} ?? .success(content))
    }
}

@MainActor final class UpdateController: ObservableObject {
    nonisolated static var currentVersion:String { Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "0.4.3" }
    @Published var available:ReleaseUpdate?
    @Published var checking = false
    @Published var installing = false
    @Published var status = ""
    @Published var showDetails = false
    @Published var completedNotes:String?
    @Published var automatic:Bool { didSet { preferences.set(automatic,forKey:"updates.automatic"); if automatic { check() } } }
    var canInstall:Bool { !preview && available != nil && !checking && !installing }
    var changed:(()->Void)?
    var finishInstallation:(()->Void)?
    private let preferences:UserDefaults
    private let preview:Bool
    private var work:Task<Void,Never>?
    private var timer:Timer?
    private var installation:UpdateCancellation?
    private var handedOff = false
    init(preferences:UserDefaults = .standard,preview:Bool = false) {
        self.preferences = preferences; self.preview = preview
        automatic = preferences.object(forKey:"updates.automatic") as? Bool ?? true
        if let data = preferences.data(forKey:"updates.cachedRelease") { available = try? ReleaseFeed.parse(data,current:Self.currentVersion) }
        if let pending = preferences.string(forKey:"updates.pendingVersion") {
            if pending == Self.currentVersion { completedNotes = preferences.string(forKey:"updates.pendingNotes") ?? "Shawn Tile is up to date."; status = "Updated to \(pending)." }
            else { status = "The update did not finish. Your previous version was kept." }
            preferences.removeObject(forKey:"updates.pendingVersion"); preferences.removeObject(forKey:"updates.pendingNotes")
        }
        if preview {
            let version = "999.0.0", name = "ShawnTile-999.0.0-universal.zip"
            let object:[String:Any] = ["tag_name":"v"+version,"html_url":"https://github.com/swright7001/shawn-tile/releases/tag/v"+version,"name":"Shawn Tile preview","body":"Grid and Rows keep your chosen layout.\n\nCheck for updates, review new features and install from the app.","draft":false,"prerelease":false,"assets":[["name":name,"browser_download_url":"https://github.com/swright7001/shawn-tile/releases/download/v"+version+"/"+name,"digest":"sha256:"+String(repeating:"0",count:64),"size":1,"state":"uploaded"]]]
            available = try? ReleaseFeed.parse(JSONSerialization.data(withJSONObject:object),current:Self.currentVersion)
        }
    }
    func start() {
        guard !preview else { return }
        timer = Timer.scheduledTimer(withTimeInterval:3600,repeats:true) { [weak self] _ in Task { @MainActor in self?.check() } }
        check()
    }
    func check(manual:Bool = false) {
        guard !preview, !checking, !installing else { return }
        let last = preferences.object(forKey:"updates.lastChecked") as? Date ?? .distantPast
        guard manual || (automatic && Date().timeIntervalSince(last) >= 86400) else { return }
        checking = true; if manual { status = "Checking for updates…" }
        work = Task {
            do {
                let data = try await ReleaseRequest(maximum:2*1024*1024,download:false).load(ReleaseFeed.latest)
                available = try ReleaseFeed.parse(data,current:Self.currentVersion)
                preferences.set(data,forKey:"updates.cachedRelease"); preferences.set(Date(),forKey:"updates.lastChecked")
                if manual { status = available.map{"Version \($0.version) is ready."} ?? "You’re up to date (\(Self.currentVersion))." }
            } catch { if manual { status = "Couldn’t check for updates. \(error.localizedDescription)" } }
            checking = false; changed?()
        }
    }
    func cancel() { work?.cancel(); installation?.cancel(); status = "Update cancelled. Your installed app was kept." }
    func shutdown() {
        timer?.invalidate()
        if !handedOff { work?.cancel(); installation?.cancel() }
    }
    func install() {
        guard !preview, let selected = available, !checking, !installing else { return }
        installing = true; status = "Downloading update…"
        work = Task {
            var directory:URL?
            do {
                // Refresh metadata before installation, including for a cached banner.
                let metadata = try await ReleaseRequest(maximum:2*1024*1024,download:false).load(ReleaseFeed.latest)
                let latest = try ReleaseFeed.parse(metadata,current:Self.currentVersion)
                guard latest == selected else { available = latest; throw UpdateError.invalid("The release changed. Review its latest features before updating.") }
                let data = try await ReleaseRequest(maximum:ReleaseFeed.maximumArchiveSize,download:true).load(selected.download)
                try Task.checkCancellation()
                let root = FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("Shawn Tile/Updates",isDirectory:true)
                try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
                let folder = root.appendingPathComponent(UUID().uuidString,isDirectory:true); directory = folder
                try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
                let archive = folder.appendingPathComponent("update.zip"); try data.write(to:archive,options:.atomic)
                status = "Verifying update…"
                let current = Bundle.main.bundleURL
                let cancellation = UpdateCancellation(); installation = cancellation
                let stage = try await Task.detached { try UpdateInstaller.prepare(archive:archive,update:selected,current:current,work:folder,cancellation:cancellation) }.value
                do {
                    try Task.checkCancellation()
                    guard let resource = Bundle.main.url(forResource:"update-helper",withExtension:"sh") else { throw UpdateError.invalid("The update installer is missing. Please download the app again.") }
                    let helper = stage.appendingPathComponent("update-helper.sh")
                    try FileManager.default.copyItem(at:resource,to:helper)
                    let log = folder.appendingPathComponent("install.log"); FileManager.default.createFile(atPath:log.path,contents:nil,attributes:[.posixPermissions:0o600])
                    let task = Process(); task.executableURL = URL(fileURLWithPath:"/bin/bash")
                    task.arguments = [helper.path,String(getpid()),stage.path,current.path]
                    let output = try FileHandle(forWritingTo:log); task.standardOutput = output; task.standardError = output
                    try task.run(); try? output.close()
                    preferences.set(selected.version,forKey:"updates.pendingVersion"); preferences.set(selected.notes,forKey:"updates.pendingNotes")
                    status = "Restarting to finish the update…"; handedOff = true; showDetails = false
                    // Leave the SwiftUI action before closing native sheets and quitting.
                    DispatchQueue.main.async { [self] in
                        if let finishInstallation { finishInstallation() }
                        else { NSApp.terminate(nil) }
                    }
                } catch { try? FileManager.default.removeItem(at:stage); throw error }
            } catch {
                status = Task.isCancelled ? "Update cancelled. Your installed app was kept." : error.localizedDescription
                installing = false; installation = nil
                if let directory { try? FileManager.default.removeItem(at:directory) }
            }
        }
    }
    deinit { timer?.invalidate(); work?.cancel() }
}

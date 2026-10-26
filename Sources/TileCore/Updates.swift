import Foundation
import CryptoKit

public struct AppVersion: Comparable, Equatable {
    public let parts: [Int]
    public init?(_ value:String) {
        let text = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let fields = text.split(separator:".",omittingEmptySubsequences:false)
        guard fields.count == 3 else { return nil }
        var numbers:[Int] = []
        for field in fields {
            guard !field.isEmpty, field.allSatisfy({$0.isASCII && $0.isNumber}),
                  (field.count == 1 || field.first != "0"), let number = Int(field), number <= 999999 else { return nil }
            numbers.append(number)
        }
        parts = numbers
    }
    public static func < (a:Self,b:Self) -> Bool { a.parts.lexicographicallyPrecedes(b.parts) }
}
public struct ReleaseUpdate: Codable, Equatable {
    public let version:String
    public let title:String
    public let notes:String
    public let page:URL
    public let download:URL
    public let sha256:String
    public let size:Int
    public var summary:String {
        notes.split(separator:"\n").map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }
            .first(where:{!$0.isEmpty}).map { String($0.prefix(220)) } ?? "A new version of Shawn Tile is ready."
    }
}
public enum UpdateError: LocalizedError {
    case invalid(String)
    public var errorDescription:String? { if case let .invalid(message) = self { return message }; return nil }
}
public enum ReleaseFeed {
    public static let repository = "swright7001/shawn-tile"
    public static let latest = URL(string:"https://api.github.com/repos/\(repository)/releases/latest")!
    public static let releases = URL(string:"https://github.com/\(repository)/releases/latest")!
    public static let maximumArchiveSize = 64 * 1024 * 1024
    private struct Release:Decodable {
        let tag_name:String, html_url:URL, draft:Bool, prerelease:Bool
        let name:String?, body:String?, assets:[Asset]
    }
    private struct Asset:Decodable {
        let name:String, browser_download_url:URL, digest:String?, size:Int, state:String
    }
    public static func trustedURL(_ url:URL,download:Bool = false) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443, url.fragment == nil else { return false }
        if download { return ["github.com","release-assets.githubusercontent.com"].contains(url.host?.lowercased() ?? "") }
        return url.host?.lowercased() == "api.github.com" && url.path == "/repos/\(repository)/releases/latest" && url.query == nil
    }
    public static func parse(_ data:Data,current:String) throws -> ReleaseUpdate? {
        guard data.count <= 2*1024*1024, let running = AppVersion(current) else { throw UpdateError.invalid("The installed version could not be read.") }
        let release = try JSONDecoder().decode(Release.self,from:data)
        guard !release.draft, !release.prerelease, let version = AppVersion(release.tag_name) else { throw UpdateError.invalid("The release is not a supported stable version.") }
        guard version > running else { return nil }
        let tag = release.tag_name
        let canonical = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let page = URL(string:"https://github.com/\(repository)/releases/tag/\(tag)")!
        guard release.html_url == page else { throw UpdateError.invalid("The release belongs to an unexpected source.") }
        let expected = "ShawnTile-\(canonical)-universal.zip"
        let matches = release.assets.filter{$0.name == expected}
        guard matches.count == 1, let asset = matches.first, asset.state == "uploaded",
              asset.size > 0, asset.size <= maximumArchiveSize,
              let digest = asset.digest, digest.hasPrefix("sha256:"),
              digest.count == 71, digest.dropFirst(7).allSatisfy({$0.isHexDigit && $0.isASCII}),
              asset.browser_download_url == URL(string:"https://github.com/\(repository)/releases/download/\(tag)/\(expected)") else {
            throw UpdateError.invalid("This release does not have a verified universal update archive yet.")
        }
        return ReleaseUpdate(version:canonical,title:release.name ?? "Shawn Tile \(canonical)",notes:String((release.body ?? "").prefix(40000)),page:page,download:asset.browser_download_url,sha256:String(digest.dropFirst(7)).lowercased(),size:asset.size)
    }
    public static func verifyArchive(_ url:URL,update:ReleaseUpdate) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath:url.path)
        guard attributes[.size] as? Int == update.size else { throw UpdateError.invalid("The update download is incomplete or has an unexpected size. Please try again.") }
        let handle = try FileHandle(forReadingFrom:url); defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount:1024*1024), !chunk.isEmpty { hash.update(data:chunk) }
        let actual = hash.finalize().map{String(format:"%02x",$0)}.joined()
        guard actual == update.sha256 else { throw UpdateError.invalid("The update checksum does not match GitHub. The installed app was kept.") }
    }
}

import Foundation

/// Validate the ZIP directory before the system extractor can create any files.
/// Native releases do not need symlinks, encryption, split ZIPs or ZIP64.
public enum UpdateArchive {
    public static func validate(_ data:Data) throws {
        let bytes = [UInt8](data)
        func value(_ offset:Int,_ length:Int) throws -> Int {
            guard offset >= 0, offset+length <= bytes.count else { throw UpdateError.invalid("The update archive is truncated.") }
            return (0..<length).reduce(0) { $0 | (Int(bytes[offset+$1]) << (8*$1)) }
        }
        func require(_ valid:Bool) throws { if !valid { throw UpdateError.invalid("The update archive has unsupported or unsafe contents.") } }
        try require(bytes.count >= 22 && bytes.count <= ReleaseFeed.maximumArchiveSize)
        var end:Int?
        for position in stride(from:bytes.count-22,through:max(0,bytes.count-65557),by:-1) {
            if try value(position,4) == 0x06054b50, try position+22+value(position+20,2) == bytes.count { end = position; break }
        }
        guard let end else { throw UpdateError.invalid("The update is not a complete ZIP archive.") }
        try require(value(end+4,2) == 0 && value(end+6,2) == 0)
        let count = try value(end+10,2), length = try value(end+12,4), start = try value(end+16,4)
        try require(count > 0 && count <= 2000 && value(end+8,2) == count && start+length == end)
        var cursor = start, unpacked = 0, paths:Set<String> = []
        for _ in 0..<count {
            try require(value(cursor,4) == 0x02014b50 && cursor+46 <= end)
            let flags = try value(cursor+8,2), method = try value(cursor+10,2)
            let compressed = try value(cursor+20,4), size = try value(cursor+24,4)
            let names = try value(cursor+28,2), extra = try value(cursor+30,2), comment = try value(cursor+32,2)
            let external = try value(cursor+38,4), local = try value(cursor+42,4)
            let kind = (external >> 16) & 0xf000
            try require(flags & 1 == 0 && [0,8].contains(method) && [0,0x4000,0x8000].contains(kind))
            try require(names > 0 && names <= 512 && cursor+46+names+extra+comment <= end)
            guard let name = String(bytes:bytes[(cursor+46)..<(cursor+46+names)],encoding:.utf8) else { throw UpdateError.invalid("The archive contains an unsupported filename.") }
            let components = name.split(separator:"/",omittingEmptySubsequences:false)
            try require(!name.hasPrefix("/") && !name.contains("\\") && !name.unicodeScalars.contains(where:{$0.value<32 || $0.value==127}))
            try require(!components.contains("..") && !components.contains(".") && !components.dropLast().contains(""))
            try require(name.hasPrefix("Shawn Tile.app/") || name.hasPrefix("__MACOSX/"))
            let normalized = name.hasSuffix("/") ? String(name.dropLast()) : name
            try require(paths.insert(normalized).inserted)
            unpacked += size; try require(unpacked <= 128*1024*1024 && compressed <= bytes.count)
            try require(local >= 0 && local+30 <= start && value(local,4) == 0x04034b50)
            let localNames = try value(local+26,2), localExtra = try value(local+28,2)
            try require(localNames == names && local+30+localNames+localExtra+compressed <= start)
            try require(Array(bytes[(local+30)..<(local+30+localNames)]) == Array(bytes[(cursor+46)..<(cursor+46+names)]))
            try require(value(local+6,2) == flags && value(local+8,2) == method)
            cursor += 46+names+extra+comment
        }
        try require(cursor == end)
    }
}

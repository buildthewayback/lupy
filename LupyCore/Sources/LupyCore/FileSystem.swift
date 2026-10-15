// LupyCore — storage abstraction. The macOS shell provides a real implementation
// (Application Support, atomic replace, fsync); tests use the in-memory one with fault injection.

public enum FileSystemError: Error, Equatable, CustomStringConvertible, Sendable {
    case notFound(String)
    case ioFailure(String)
    case invalidPath(String)
    case simulatedCrash(String)
    public var description: String {
        switch self {
        case .notFound(let p): return "not found: \(p)"
        case .ioFailure(let m): return "I/O failure: \(m)"
        case .invalidPath(let p): return "invalid path: \(p)"
        case .simulatedCrash(let m): return "simulated crash: \(m)"
        }
    }
}

/// All paths are relative to the store root and use "/" separators.
public protocol LupyFileSystem: AnyObject {
    func read(_ path: String) throws -> [UInt8]?
    /// Write to a temporary file, flush, then atomically replace `path`.
    func writeAtomically(_ path: String, _ bytes: [UInt8]) throws
    /// Append and flush to stable storage before returning.
    func append(_ path: String, _ bytes: [UInt8]) throws
    func truncate(_ path: String, toLength length: Int) throws
    func list(_ directory: String) throws -> [String]
    func remove(_ path: String) throws
    func move(_ from: String, to: String) throws
    func makeDirectory(_ path: String) throws
    func exists(_ path: String) -> Bool
}

public enum PathRules {
    /// Rejects absolute paths, parent traversal and empty components.
    public static func validate(_ path: String) throws {
        if path.isEmpty || path.hasPrefix("/") || path.hasPrefix("~") { throw FileSystemError.invalidPath(path) }
        for comp in path.split(separator: "/", omittingEmptySubsequences: false) {
            if comp.isEmpty || comp == ".." || comp == "." { throw FileSystemError.invalidPath(path) }
        }
    }
}

/// In-memory file system with crash/fault injection for recovery tests.
public final class InMemoryFileSystem: LupyFileSystem {
    public private(set) var files: [String: [UInt8]] = [:]
    public private(set) var directories: Set<String> = [""]
    public var writeCount = 0

    /// Fail the next append after writing only this many bytes (simulates power loss mid-write).
    public var tornAppendAfterBytes: Int?
    /// Fail the next atomic write before replacing the file (simulates crash during snapshot).
    public var failNextAtomicWrite = false
    /// Fail every mutating call (disk full / permission revoked).
    public var failAllWrites = false

    public init() {}

    public func read(_ path: String) throws -> [UInt8]? { try PathRules.validate(path); return files[path] }

    public func writeAtomically(_ path: String, _ bytes: [UInt8]) throws {
        try PathRules.validate(path)
        if failAllWrites { throw FileSystemError.ioFailure("disk unavailable") }
        if failNextAtomicWrite {
            failNextAtomicWrite = false
            files[path + ".tmp"] = bytes  // temp file left behind, original untouched
            throw FileSystemError.simulatedCrash("during atomic write of \(path)")
        }
        writeCount += 1
        files[path] = bytes
        files[path + ".tmp"] = nil
    }

    public func append(_ path: String, _ bytes: [UInt8]) throws {
        try PathRules.validate(path)
        if failAllWrites { throw FileSystemError.ioFailure("disk unavailable") }
        if let n = tornAppendAfterBytes {
            tornAppendAfterBytes = nil
            files[path, default: []].append(contentsOf: bytes.prefix(max(0, min(n, bytes.count))))
            throw FileSystemError.simulatedCrash("torn append to \(path)")
        }
        writeCount += 1
        files[path, default: []].append(contentsOf: bytes)
    }

    public func truncate(_ path: String, toLength length: Int) throws {
        try PathRules.validate(path)
        guard let f = files[path] else { throw FileSystemError.notFound(path) }
        files[path] = Array(f.prefix(length))
    }

    public func list(_ directory: String) throws -> [String] {
        let prefix = directory.isEmpty ? "" : directory + "/"
        var names = Set<String>()
        for k in files.keys where k.hasPrefix(prefix) {
            let rest = k.dropFirst(prefix.count)
            if let first = rest.split(separator: "/").first { names.insert(String(first)) }
        }
        return names.sorted()
    }

    public func remove(_ path: String) throws {
        try PathRules.validate(path)
        if failAllWrites { throw FileSystemError.ioFailure("disk unavailable") }
        files[path] = nil
        for k in files.keys where k.hasPrefix(path + "/") { files[k] = nil }
    }

    public func move(_ from: String, to: String) throws {
        try PathRules.validate(from); try PathRules.validate(to)
        if failAllWrites { throw FileSystemError.ioFailure("disk unavailable") }
        guard let f = files[from] else { throw FileSystemError.notFound(from) }
        files[to] = f
        files[from] = nil
    }

    public func makeDirectory(_ path: String) throws { try PathRules.validate(path); directories.insert(path) }

    public func exists(_ path: String) -> Bool { files[path] != nil || directories.contains(path) }

    /// Test helper: corrupt bytes in a file.
    public func overwrite(_ path: String, at offset: Int, with bytes: [UInt8]) {
        guard var f = files[path], offset < f.count else { return }
        for (i, b) in bytes.enumerated() where offset + i < f.count { f[offset + i] = b }
        files[path] = f
    }

    public func setFile(_ path: String, _ bytes: [UInt8]) { files[path] = bytes }
}

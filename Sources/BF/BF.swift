/// A Brainfuck interpreter, and a Brainfuck-to-Swift compiler.
///
/// ```swift
/// var bf = try BF("+[,<>.]-")          // echo
/// print(bf.run(input: "Hello, Swift!")) // Hello, Swift!
/// ```
public struct BF: Sendable {
    /// The number of cells on the data tape.
    public static let datasize = 65536

    /// The eight Brainfuck commands.  Every other character is a comment.
    public enum Command: UInt8, Sendable, CaseIterable {
        case next  = 0x3E // >  move the pointer right
        case prev  = 0x3C // <  move the pointer left
        case incr  = 0x2B // +  increment the cell under the pointer
        case decr  = 0x2D // -  decrement the cell under the pointer
        case begin = 0x5B // [  jump past the matching ] if the cell is zero
        case end   = 0x5D // ]  jump back to the matching [ if the cell is not zero
        case put   = 0x2E // .  append the cell to the output
        case get   = 0x2C // ,  read one byte of input into the cell
    }

    /// Why a source string is not a valid Brainfuck program.
    public enum ParseError: Error, Equatable, Sendable, CustomStringConvertible {
        /// A `[` at the given UTF-8 offset never gets closed.
        case unmatchedBegin(at: Int)
        /// A `]` at the given UTF-8 offset has no `[` to close.
        case unmatchedEnd(at: Int)
        public var description: String {
            switch self {
            case .unmatchedBegin(let i): "unmatched [ at offset \(i)"
            case .unmatchedEnd(let i):   "unmatched ] at offset \(i)"
            }
        }
    }

    /// The program, with comments stripped.
    public let code: [Command]
    /// Maps the index of every `[` to its matching `]`, and vice versa.
    public let jump: [Int: Int]

    /// The data tape.
    public private(set) var data = [UInt8](repeating: 0, count: BF.datasize)
    /// The input not yet consumed by `,`.
    public private(set) var ibuf: ArraySlice<UInt8> = []
    /// Everything `.` has written so far.
    public private(set) var obuf: [UInt8] = []
    /// The program counter -- an index into `code`.
    public private(set) var pc = 0
    /// The data pointer -- an index into `data`.
    public private(set) var sp = 0

    /// Parses `src` and matches up its brackets.
    /// - Throws: ``ParseError`` if the brackets do not balance.
    public init(_ src: String) throws(ParseError) {
        var code = [Command]()
        var offsets = [Int]()   // where each command came from, for diagnostics
        for (offset, byte) in src.utf8.enumerated() {
            guard let command = Command(rawValue: byte) else { continue }
            code.append(command)
            offsets.append(offset)
        }
        var stack = [Int]()
        var jump = [Int: Int]()
        for (i, command) in code.enumerated() {
            switch command {
            case .begin:
                stack.append(i)
            case .end:
                guard let begin = stack.popLast() else {
                    throw ParseError.unmatchedEnd(at: offsets[i])
                }
                jump[begin] = i
                jump[i] = begin
            default:
                continue
            }
        }
        if let begin = stack.first {
            throw ParseError.unmatchedBegin(at: offsets[begin])
        }
        self.code = code
        self.jump = jump
    }

    /// Rewinds to the start of the program with a blank tape.
    public mutating func reset() {
        data = [UInt8](repeating: 0, count: Self.datasize)
        ibuf = []
        obuf = []
        (pc, sp) = (0, 0)
    }

    /// Executes the command under the program counter.
    /// The tape is circular: moving past either end wraps around to the other.
    /// - Returns: `false` once the program halts -- either the end of the code,
    ///   or a `,` with no input left.
    @discardableResult
    public mutating func step() -> Bool {
        guard code.indices.contains(pc) else { return false }
        switch code[pc] {
        case .next:  sp = (sp + 1) % data.count
        case .prev:  sp = (sp + data.count - 1) % data.count
        case .incr:  data[sp] &+= 1
        case .decr:  data[sp] &-= 1
        case .begin: if data[sp] == 0 { pc = jump[pc]! }
        case .end:   if data[sp] != 0 { pc = jump[pc]! }
        case .put:   obuf.append(data[sp])
        case .get:
            guard let byte = ibuf.popFirst() else { return false }
            data[sp] = byte
        }
        pc += 1
        return true
    }

    /// Runs the program from the beginning and returns everything it wrote.
    public mutating func run(input: String = "") -> String {
        reset()
        ibuf = ArraySlice(input.utf8)
        while step() {}
        return String(decoding: obuf, as: UTF8.self)
    }

    /// Translates `src` into an equivalent, standalone Swift program.
    public static func compile(_ src: String) -> String {
        var lines = [
            "#if canImport(Darwin)",
            "import Darwin",
            "#else",
            "import Glibc",
            "#endif",
            "var data = [UInt8](repeating: 0, count: \(datasize))",
            "var sp = 0",
        ]
        var depth = 0
        func append(_ line: String) {
            lines.append(String(repeating: "    ", count: depth) + line)
        }
        for byte in src.utf8 {
            guard let command = Command(rawValue: byte) else { continue }
            switch command {
            case .next:  append("sp = (sp + 1) % data.count")
            case .prev:  append("sp = (sp + data.count - 1) % data.count")
            case .incr:  append("data[sp] &+= 1")
            case .decr:  append("data[sp] &-= 1")
            case .begin: append("while data[sp] != 0 {"); depth += 1
            case .end:   depth = max(0, depth - 1); append("}")
            case .put:   append("putchar(Int32(data[sp]))")
            case .get:   append("data[sp] = UInt8(truncatingIfNeeded: max(0, getchar()))")
            }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }
}

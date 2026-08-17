/// A Brainfuck interpreter, and a Brainfuck-to-Swift compiler.
///
/// ```swift
/// var bf = try BF("+[,<>.]-")           // echo
/// print(bf.run(input: "Hello, Swift!")) // Hello, Swift!
/// ```
///
/// A `!` in the source ends the program and makes everything after it the
/// program's input, so a program can carry its own data:
///
/// ```swift
/// var bf = try BF("+[,<>.]-!Hello, Swift!")
/// print(bf.run())                       // Hello, Swift!
/// ```
public struct BF: Sendable {
    /// The number of cells on the data tape.
    public static let datasize = 65536

    /// Separates the program from its input.  Everything after the first `!`
    /// in a source string is data rather than code.
    public static let inputSeparator = UInt8(ascii: "!")

    /// The eight Brainfuck commands.  Every other character is a comment,
    /// except `!`, which ends the program -- see ``inputSeparator``.
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
    /// The input carried in the source after `!`; empty if there was no `!`.
    public let embeddedInput: [UInt8]

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

    /// Splits a source string at the first `!` into program and input.
    /// Both halves are byte offsets into `src`, so diagnostics stay accurate.
    static func split(_ src: String) -> (program: ArraySlice<UInt8>, input: [UInt8]) {
        let bytes = Array(src.utf8)
        guard let bang = bytes.firstIndex(of: inputSeparator) else {
            return (bytes[...], [])
        }
        return (bytes[..<bang], Array(bytes[bytes.index(after: bang)...]))
    }

    /// Parses `src` and matches up its brackets.
    ///
    /// Everything after the first `!` becomes ``embeddedInput`` rather than
    /// code, so brackets in the input section are data and do not have to
    /// balance.
    /// - Throws: ``ParseError`` if the brackets in the program do not balance.
    public init(_ src: String) throws(ParseError) {
        let (program, input) = Self.split(src)
        self.embeddedInput = input
        var code = [Command]()
        var offsets = [Int]()   // where each command came from, for diagnostics
        for (offset, byte) in program.enumerated() {
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
        self.ibuf = input[...]
    }

    /// Rewinds to the start of the program with a blank tape, ready to be
    /// stepped again.  Any ``embeddedInput`` is restored along with it.
    public mutating func reset() {
        data = [UInt8](repeating: 0, count: Self.datasize)
        ibuf = embeddedInput[...]
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
    /// - Parameter input: The input to feed `,`.  Defaults to ``embeddedInput``
    ///   -- the text after `!` in the source, or nothing if there was no `!`.
    ///   Passing a value overrides it.
    public mutating func run(input: String? = nil) -> String {
        reset()
        if let input { ibuf = ArraySlice(input.utf8) }
        while step() {}
        return String(decoding: obuf, as: UTF8.self)
    }

    /// Translates `src` into an equivalent, standalone Swift program.
    ///
    /// If `src` carries its own input after a `!`, that input is baked into
    /// the generated program and `,` reads from it.  Otherwise `,` reads
    /// stdin, storing 0 at end of input.
    public static func compile(_ src: String) -> String {
        let (program, input) = split(src)
        var lines = [
            "#if canImport(Darwin)",
            "import Darwin",
            "#else",
            "import Glibc",
            "#endif",
            "var data = [UInt8](repeating: 0, count: \(datasize))",
            "var sp = 0",
        ]
        if !input.isEmpty {
            lines.append("var input = Array(\(literal(input)).utf8)[...]")
        }
        var depth = 0
        func append(_ line: String) {
            lines.append(String(repeating: "    ", count: depth) + line)
        }
        for byte in program {
            guard let command = Command(rawValue: byte) else { continue }
            switch command {
            case .next:  append("sp = (sp + 1) % data.count")
            case .prev:  append("sp = (sp + data.count - 1) % data.count")
            case .incr:  append("data[sp] &+= 1")
            case .decr:  append("data[sp] &-= 1")
            case .begin: append("while data[sp] != 0 {"); depth += 1
            case .end:   depth = max(0, depth - 1); append("}")
            case .put:   append("putchar(Int32(data[sp]))")
            case .get:
                if input.isEmpty {
                    append("data[sp] = UInt8(truncatingIfNeeded: max(0, getchar()))")
                } else {
                    append("data[sp] = input.popFirst() ?? 0")
                }
            }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// Renders `bytes` as a Swift string literal, for embedding in generated
    /// source.  The bytes always came from a `String`, so they are valid UTF-8.
    static func literal(_ bytes: [UInt8]) -> String {
        var out = "\""
        for scalar in String(decoding: bytes, as: UTF8.self).unicodeScalars {
            switch scalar {
            case "\\": out += #"\\"#
            case "\"": out += #"\""#
            case "\n": out += #"\n"#
            case "\r": out += #"\r"#
            case "\t": out += #"\t"#
            case "\0": out += #"\0"#
            default:
                if scalar.value < 0x20 || scalar.value == 0x7F {
                    out += #"\u{"# + String(scalar.value, radix: 16) + "}"
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}

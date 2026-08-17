import Testing
@testable import BF

@Suite("BF")
struct BFTests {
    /// The canonical "Hello World!" program.
    static let helloWorldSource = """
        ++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]\
        >>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.
        """

    @Test("echoes its input")
    func echo() throws {
        var bf = try BF("+[,<>.]-")
        #expect(bf.run(input: "Hello, Swift!") == "Hello, Swift!")
    }

    @Test("runs Hello World!")
    func helloWorld() throws {
        var bf = try BF(Self.helloWorldSource)
        #expect(bf.run() == "Hello World!\n")
    }

    @Test("treats anything but the eight commands as a comment")
    func comments() throws {
        var bf = try BF("+ [ read , then write . ] -")
        #expect(bf.code.count == 6)
        #expect(bf.run(input: "swift") == "swift")
    }

    @Test("is rewound by run(), so it can be run repeatedly")
    func rerun() throws {
        var bf = try BF("+[,<>.]-")
        #expect(bf.run(input: "once") == "once")
        #expect(bf.run(input: "twice") == "twice")
    }

    @Test("can be driven one step at a time")
    func stepping() throws {
        var bf = try BF("++")
        #expect(bf.step() == true)
        #expect(bf.data[0] == 1)
        #expect(bf.step() == true)
        #expect(bf.data[0] == 2)
        #expect(bf.step() == false) // end of code
    }

    @Test("wraps cells around at the byte boundary")
    func wrapping() throws {
        var bf = try BF("-")
        bf.step()
        #expect(bf.data[0] == 255)
        var up = try BF(String(repeating: "+", count: 256))
        while up.step() {}
        #expect(up.data[0] == 0)
    }

    @Test("wraps the pointer around either end of the tape")
    func tapeBounds() throws {
        var left = try BF("<")
        left.step()
        #expect(left.sp == BF.datasize - 1)
        var right = try BF(String(repeating: ">", count: BF.datasize))
        while right.step() {}
        #expect(right.sp == 0)
    }

    @Test("rejects unbalanced brackets")
    func unbalanced() {
        #expect(throws: BF.ParseError.unmatchedEnd(at: 1)) { try BF("+]") }
        #expect(throws: BF.ParseError.unmatchedBegin(at: 1)) { try BF("+[") }
        #expect(throws: BF.ParseError.unmatchedBegin(at: 0)) { try BF("[[]") }
    }

    @Test("compiles to Swift that mirrors the source")
    func compile() {
        #expect(BF.compile("+[,<>.]-").hasSuffix("""
            data[sp] &+= 1
            while data[sp] != 0 {
                data[sp] = UInt8(truncatingIfNeeded: max(0, getchar()))
                sp = (sp + data.count - 1) % data.count
                sp = (sp + 1) % data.count
                putchar(Int32(data[sp]))
            }
            data[sp] &-= 1

            """))
    }

    @Test("compiles comments away")
    func compileComments() {
        #expect(BF.compile("+ increment") == BF.compile("+"))
    }
}

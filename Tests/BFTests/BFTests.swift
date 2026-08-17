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

    // MARK: - the ! extension

    @Test("takes its input from the source after !")
    func embeddedInput() throws {
        var bf = try BF("+[,<>.]-!Hello, Swift!")
        #expect(bf.run() == "Hello, Swift!")
    }

    @Test("splits on the first ! only, so the input may contain more")
    func firstBangWins() throws {
        var bf = try BF("+[,.]!a!b!c")
        #expect(bf.embeddedInput == Array("a!b!c".utf8))
        #expect(bf.run() == "a!b!c")
    }

    @Test("treats the input section as data, not code")
    func inputIsNotCode() throws {
        // The unbalanced [ and the +- after ! must not be parsed as commands.
        var bf = try BF("+[,.]![+-")
        #expect(bf.code.count == 5)
        #expect(bf.run() == "[+-")
    }

    @Test("has no embedded input when the source has no !")
    func noBang() throws {
        var bf = try BF("+[,.]")
        #expect(bf.embeddedInput.isEmpty)
        #expect(bf.run() == "")
        #expect(bf.run(input: "still works") == "still works")
    }

    @Test("lets an explicit input: argument override the embedded one")
    func explicitInputWins() throws {
        var bf = try BF("+[,.]!embedded")
        #expect(bf.run(input: "explicit") == "explicit")
        #expect(bf.run() == "embedded")   // and the embedded input survives
    }

    @Test("restores the embedded input on reset(), so stepping works")
    func embeddedInputSurvivesReset() throws {
        var bf = try BF("+[,.]!hi")
        while bf.step() {}
        #expect(String(decoding: bf.obuf, as: UTF8.self) == "hi")
        bf.reset()
        #expect(bf.ibuf.elementsEqual(Array("hi".utf8)))
    }

    @Test("bakes the embedded input into the compiled program")
    func compileEmbeddedInput() {
        let swift = BF.compile("+[,.]!hi")
        #expect(swift.contains(#"var input = Array("hi".utf8)[...]"#))
        #expect(swift.contains("data[sp] = input.popFirst() ?? 0"))
        #expect(!swift.contains("getchar()"))
        // Without a !, the generated program still reads stdin.
        #expect(BF.compile("+[,.]").contains("getchar()"))
    }

    @Test("escapes the embedded input it emits as a Swift literal")
    func compileEscapesInput() {
        #expect(BF.literal(Array(#"a"b\c"#.utf8)) == #""a\"b\\c""#)
        #expect(BF.literal(Array("tab\tnl\n".utf8)) == #""tab\tnl\n""#)
        #expect(BF.literal([0x01]) == #""\u{1}""#)
        #expect(BF.literal(Array("Swift".utf8)) == #""Swift""#)
    }
}

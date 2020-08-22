public struct BF {
    public static var datasize:Int { return 65536 }
    static func str2chars(_ s:String) -> [CChar] {
        var cs = [CChar]()
        for c in s.utf8 { cs.append(CChar(c)) }
        return cs
    }
    let code:[CChar]
    let jump:Dictionary<Int,Int>
    public init?(_ src:String) {
        self.code = Self.str2chars(src)
        var stak:[Int] = []
        var jump:Dictionary<Int,Int> = [:]
        for (i,c) in code.enumerated() {
            let u = UnicodeScalar(Int(c))
            // println("\(i)=>\(u)")
            if u == "[" {
                stak.append(i)
            } else if u == "]" {
                if stak.isEmpty { /* error = "too many ]s" */ return nil }
                let f = stak.removeLast()
                jump[f] = i
                jump[i] = f
            }
        }
        if !stak.isEmpty { /* error = "too many [s" */ return nil }
        self.jump = jump
    }
    public func run(input:String = "") -> String {
        var data = [CChar](repeating: CChar(0), count:Self.datasize)
        var ibuf = Self.str2chars(input)
        var obuf = [CChar]()
        var (pc, sp) = (0, 0)
        loop: while 0 <= pc && pc < code.count {
            switch UnicodeScalar(Int(code[pc])) {
            case ">": sp += 1
            case "<": sp -= 1
            case "+": data[sp] += 1
            case "-": data[sp] -= 1
            case "[":
                if data[sp] == CChar(0) { pc = jump[pc]! }
            case "]":
                if data[sp] != CChar(0) { pc = jump[pc]! }
            case ".":
                obuf.append(data[sp])
            case ",":
                if ibuf.isEmpty {
                    break loop
                } else {
                    data[sp] = ibuf.remove(at:0)
                }
            default:
                continue
            }
            pc += 1
        }
        obuf.append(CChar(0)) // \0 Terminate
        return String(cString:&obuf)
    }
    public static func compile(src:String) -> String {
        var datasize:Int { return 65536 }
        var lines = [
            "import Darwin",
            "var data = [CChar](repeating: CChar(0), count:\(datasize))",
            "var (sp, pc) = (0, 0)",
        ];
        for c in src {
            switch c {
            case ">": lines.append("sp+=1")
            case "<": lines.append("sp-=1")
            case "+": lines.append("data[sp]+=1")
            case "-": lines.append("data[sp]-=1")
            case "[": lines.append("while data[sp] != CChar(0) {")
            case "]": lines.append("}")
            case ".": lines.append("putchar(Int32(data[sp]))")
            case ",": lines.append(
                "data[sp] = {c in CChar(c < 0 ? 0 : c)}(getchar())"
                )
            default:
                continue
            }
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }
}

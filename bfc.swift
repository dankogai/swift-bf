//
//  bfc.swift
//  bf
//
//  Created by Dan Kogai on 6/27/14.
//  Copyright (c) 2014 Dan Kogai. All rights reserved.
//
func bfc(src:String) -> String {
    var datasize:Int { return 65536 }
    var lines = [
        "import Darwin",
        "var data = [CChar](count:\(datasize), repeatedValue:CChar(0))",
        "var (sp, pc) = (0, 0)",
    ];
    for c in src {
        switch c {
        case ">": lines.append("sp++")
        case "<": lines.append("sp--")
        case "+": lines.append("data[sp]++")
        case "-": lines.append("data[sp]--")
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
    return Swift.join("\n", lines)
}

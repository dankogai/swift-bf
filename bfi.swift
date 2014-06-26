//
//  bfi.swift
//  bf
//
//  Created by Dan Kogai on 6/27/14.
//  Copyright (c) 2014 Dan Kogai. All rights reserved.
//

class BFI {
    class var datasize:Int { return 65536 }
    func str2chars(s:String) -> CChar[] {
        var cs = CChar[]()
        for c in s.utf8 { cs += CChar(c) }
        return cs
    }
    @lazy var error:String? = nil
    @lazy var code:CChar[]  = []
    @lazy var jump:Dictionary<Int,Int> = [:]
    var data:CChar[] = []
    var ibuf:CChar[] = []
    var obuf:CChar[] = []
    var (pc, sp) = (0, 0)
    init(_ src:String) {
        code = str2chars(src)
        var stak:Int[] = []
        for (i,c) in enumerate(code) {
            let u = UnicodeScalar(Int(c))
            // println("\(i)=>\(u)")
            if u == "[" {
                stak.append(i)
            } else if u == "]" {
                if stak.isEmpty { error = "too many ]s"; return }
                let f = stak.removeLast()
                jump[f] = i
                jump[i] = f
            }
        }
        if !stak.isEmpty { error = "too many [s"; return }
    }
    func run(input:String = "") -> String? {
        if error {
            println("Brainfuck syntax error: \(error)")
            return nil
        }
        data = CChar[](count:BFI.datasize, repeatedValue:CChar(0))
        ibuf = str2chars(input)
        obuf = CChar[]()
        (pc, sp) = (0, 0)
        loop: for ; 0 <= pc && pc < code.count; pc++ {
            switch UnicodeScalar(Int(code[pc])) {
            case ">": sp++ ;
            case "<": sp-- ;
            case "+": data[sp]++
            case "-": data[sp]--
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
                    data[sp] = ibuf.removeAtIndex(0)
                }
            default:
                continue
            }
        }
        obuf.append(CChar(0)) // \0 Terminate
        return obuf.withUnsafePointerToElements {
            p in String.fromCString(p)
        }
    }
}

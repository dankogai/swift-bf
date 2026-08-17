[![Swift 6](https://img.shields.io/badge/swift-6-green.svg)](https://swift.org)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/dankogai/swift-bf/actions/workflows/swift.yml/badge.svg)](https://github.com/dankogai/swift-bf/actions/workflows/swift.yml)

swift-bf
========

Brainfuck Interpreter/Compiler in Swift

## SYNOPSIS

### Interpreter

```swift
import BF
var bf = try BF("+[,<>.]-")            // echo
print(bf.run(input: "Hello, Swift!"))  // Hello, Swift!
```

`BF.init` throws a `BF.ParseError` if the brackets do not balance:

```swift
do {
    _ = try BF("+[")
} catch {
    print(error)  // unmatched [ at offset 1
}
```

You can also drive the machine one command at a time.  `step()` returns
`false` once the program halts, and `pc`, `sp`, `data` and `obuf` are all
readable as it goes:

```swift
var bf = try BF("++")
while bf.step() {}
print(bf.data[0])  // 2
```

### The `!` extension

A `!` ends the program, and everything after it is the program's input, so a
source can carry its own data:

```swift
var bf = try BF("+[,<>.]-!Hello, Swift!")
print(bf.run())  // Hello, Swift!
```

The text after `!` is available as `embeddedInput`, and is what `run()` feeds
`,` by default.  Passing `input:` explicitly overrides it for that run without
discarding it:

```swift
var bf = try BF("+[,.]!embedded")
print(bf.run(input: "explicit"))  // explicit
print(bf.run())                   // embedded
```

Only the first `!` splits the source, so the input may contain more of them --
which is why `"+[,<>.]-!Hello, Swift!"` echoes the trailing `!` too.

### Compiler

```swift
import BF
print(BF.compile("+[,<>.]-"))
```

prints

```swift
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
var data = [UInt8](repeating: 0, count: 65536)
var sp = 0
data[sp] &+= 1
while data[sp] != 0 {
    data[sp] = UInt8(truncatingIfNeeded: max(0, getchar()))
    sp = (sp + data.count - 1) % data.count
    sp = (sp + 1) % data.count
    putchar(Int32(data[sp]))
}
data[sp] &-= 1
```

which compiles and runs standalone:

```sh
swift run bf | tail -n +2 > echo.swift
swiftc -o echo echo.swift
echo 'Hello, Swift!' | ./echo
```

A source using `!` compiles to a self-contained program that needs no stdin --
the input is baked in and `,` reads from it:

```swift
print(BF.compile("+[,<>.]-!Hello, Swift!"))
```

emits the same program as above, but with

```swift
var input = Array("Hello, Swift!".utf8)[...]
```

after the preamble, and `,` compiled to

```swift
data[sp] = input.popFirst() ?? 0
```

## Semantics

* The tape is 65536 cells of `UInt8`.  Cells wrap around: `-` on a zero cell
  yields 255.
* The tape is circular.  `<` on cell 0 moves to cell 65535, and `>` on the
  last cell moves back to cell 0.
* `!` ends the program; everything after the first one is input, not code.
  Brackets in the input section are data and need not balance.
* Any other character outside the input section is a comment.
* On end of input, `,` halts the interpreter, whereas compiled code follows
  the other common convention and stores 0.

## Usage

### Swift Package Manager

Add it to the `dependencies` of your `Package.swift`:

```swift
let package = Package(
  // ...
  dependencies: [
    .package(url: "https://github.com/dankogai/swift-bf.git", from: "0.0.1")
  ],
  targets: [
    .target(name: "YourTarget", dependencies: [
      .product(name: "BF", package: "swift-bf")
    ])
  ]
)
```

### Build and test locally

```sh
swift build
swift test
swift run bf
```

## Requirements

Swift 6.0 or later.

[![Swift 6](https://img.shields.io/badge/swift-6-orange.svg)](https://swift.org)
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

## Semantics

* The tape is 65536 cells of `UInt8`.  Cells wrap around: `-` on a zero cell
  yields 255.
* The tape is circular.  `<` on cell 0 moves to cell 65535, and `>` on the
  last cell moves back to cell 0.
* Any character other than `> < + - [ ] . ,` is a comment.
* On end of input, `,` halts the interpreter, whereas compiled code follows
  the other common convention and stores 0.

## Usage

### Swift Package Manager

Add it to the `dependencies` of your `Package.swift`:

```swift
let package = Package(
  // ...
  dependencies: [
    .package(url: "https://github.com/dankogai/swift-bf.git", branch: "main")
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

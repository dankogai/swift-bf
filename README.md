swift-bf
========

Brainfuck Interpreter/Compiler in Swift

## SYNOPSIS

### Interpreter

```swift
import BF
var bf = BF("+[,<>.]-")!  // echo
print(bf.run(input:"Hello, Swift!")); // Hello, Swift!
```

### Compiler

```swift
import BF
print(BF.compile("+[,<>.]-"));
```

prints

```swift
import Darwin
var data = [CChar](repeating: CChar(0), count:65536)
var (sp, pc) = (0, 0)
data[sp]+=1
while data[sp] != CChar(0) {
data[sp] = {c in CChar(c < 0 ? 0 : c)}(getchar())
sp-=1
sp+=1
putchar(Int32(data[sp]))
}
data[sp]-=1

```

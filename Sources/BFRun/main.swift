//
//  main.swift
//  bf
//
//  Created by Dan Kogai on 6/26/14.
//  Copyright (c) 2014 Dan Kogai. All rights reserved.
//
// "+[,<>.]-" is echo, exercising all eight commands.
// The minimal echo, "+[,.]", would do just as well.
import BF

let echo = "+[,<>.]-"
var bf = try BF(echo)
print(bf.run(input: "Hello, Swift!"))
print(BF.compile(echo))

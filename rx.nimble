# Package

version       = "0.1.0"
author        = "Andrea Ferretti"
description   = "Reactive Extensions for Nim"
license       = "MIT"
binDir        = "bin"
srcDir        = "src"
bin           = @["rx"]

# Dependencies

requires "nim >= 0.17.0"

task test, "test rx":
  --run
  --path: "src"
  setCommand "c", "tests/test.nim"
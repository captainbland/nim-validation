# Package

version       = "0.1.0"
author        = "captainbland"
description   = "Field validation for Nim objects"
license       = "GPLv3"
srcDir        = "src"

# Dependencies

requires "nim >= 0.18.0"

task docs, "Docs":
  exec "nim doc2 --project -o ./src/validation.nim"
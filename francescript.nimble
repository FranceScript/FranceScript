# Package

version       = "1.0.0"
author        = "FranceScript Team"
description   = "A French programming language transpiler to Nim"
license       = "MIT"
srcDir        = "src"
bin           = @["main"]
binDir        = "bin"

# Dependencies

requires "nim >= 1.6.0"

# Tasks

task test, "Run tests":
  exec "nim c -r tests/test_main.nim"

task build, "Build the transpiler":
  exec "nim c -d:release --out:bin/francescript src/main.nim"

task install_local, "Install locally":
  exec "nim c -d:release --out:francescript src/main.nim"
  exec "chmod +x francescript"
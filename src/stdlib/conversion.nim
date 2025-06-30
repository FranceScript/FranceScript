# Standard Library - Type Conversion Module
# Provides automatic conversion between numbers and strings

import strutils

proc `$`*(x: SomeNumber): string =
  when x is float or x is float32 or x is float64:
    formatFloat(x, ffDefault, -1)
  else:
    $x

template toStr*(x: untyped): string =
  when x is string:
    x
  else:
    $x

proc `+`*(s: string, n: SomeNumber): string =
  s & $n

proc `+`*(n: SomeNumber, s: string): string =
  $n & s

proc `+`*(s1: string, s2: string): string =
  s1 & s2

proc toNum*(s: string): float =
  try:
    parseFloat(s)
  except ValueError:
    0.0

proc toInt*(s: string): int =
  try:
    parseInt(s)
  except ValueError:
    0
# Standard Library - Console Module
# Provides basic console input/output operations
# Includes functions for writing messages, reading input, and flushing output


proc ecrire*(message: string) =
  echo message
  stdout.flushFile()

proc ajouterALaLigne*(message: string) =
  stdout.write(message)

proc lire*(): string =
  return readLine(stdin)
import os, strutils, sequtils, random, osproc
import types, lexer, parser, codegen

type
  Platform = enum
    macos, windows, linux

proc generateRandomId(): string =
  randomize()
  result = ""
  for i in 0..7:
    result.add(toHex(rand(255), 2).toLowerAscii())

proc processImports(inputFile: string, processedFiles: var seq[string]): seq[string] =
  let absolutePath = absolutePath(inputFile)
  
  if absolutePath in processedFiles:
    return @[]
  processedFiles.add(absolutePath)
  
  let source = readFile(inputFile)
  var lexer = newLexer(source)
  let tokens = lexer.tokenize()
  var parser = newParser(tokens)
  let ast = parser.parse()
  
  var filesToProcess: seq[string] = @[]
  
  for node in ast.body:
    if node.nodeType == "ImportDeclaration":
      let importNode = cast[ImportDeclaration](node)
      let importPath = inputFile.parentDir() / importNode.path
      if fileExists(importPath):
        let subFiles = processImports(importPath, processedFiles)
        filesToProcess.add(subFiles)
        filesToProcess.add(importPath)
  
  return filesToProcess

proc transpileFile(inputFile: string, stdlibPrefix: string = ""): string =
  let source = readFile(inputFile)
  var lexer = newLexer(source)
  let tokens = lexer.tokenize()
  var parser = newParser(tokens)
  let ast = parser.parse()
  
  var codegen = newNimCodeGenerator(stdlibPrefix)
  return codegen.generate(ast)

proc getTargetPlatform(args: seq[string]): Platform =
  for i, arg in args:
    if (arg == "--target" or arg == "-t") and i + 1 < args.len:
      let target = args[i + 1].toLowerAscii()
      case target:
      of "macos": return macos
      of "windows": return windows
      of "linux": return linux
      else: discard
  
  # Detect platform automatically
  when defined(macosx):
    return macos
  elif defined(windows):
    return windows
  else:
    return linux

proc getNimCompileCommand(target: Platform, nimFile: string): string =
  let baseCmd = "nim c"
  
  case target:
  of macos:
    return baseCmd & " --os:macosx \"" & nimFile & "\""
  of windows:
    return baseCmd & " --os:windows \"" & nimFile & "\""
  of linux:
    return baseCmd & " --os:linux \"" & nimFile & "\""

proc copyStdlib(tempDir: string, stdlibPrefix: string) =
  let stdlibSource = getCurrentDir() / "src" / "stdlib"
  if not dirExists(stdlibSource):
    return
  
  let files = toSeq(walkDir(stdlibSource))
  let nimFiles = files.filterIt(it.path.endsWith(".nim")).mapIt(it.path.extractFilename)
  let frFiles = files.filterIt(it.path.endsWith(".fr")).mapIt(it.path.extractFilename)
  
  var mainStdlibContent = "# Standard Library - Auto-generated\n\n"
  
  for file in nimFiles:
    let baseName = file.changeFileExt("")
    mainStdlibContent.add("include \"./" & baseName & "_" & stdlibPrefix[4..^1] & "\"\n")
  
  for file in frFiles:
    let baseName = file.changeFileExt("")
    mainStdlibContent.add("include \"./" & baseName & "_" & stdlibPrefix[4..^1] & "\"\n")
  
  let mainStdlibFile = tempDir / (stdlibPrefix & ".nim")
  writeFile(mainStdlibFile, mainStdlibContent)
  
  for file in nimFiles:
    let srcFile = stdlibSource / file
    let baseName = file.changeFileExt("")
    let randomizedName = baseName & "_" & stdlibPrefix[4..^1] & ".nim"
    let destFile = tempDir / randomizedName
    copyFile(srcFile, destFile)
  
  for file in frFiles:
    let srcFile = stdlibSource / file
    let frContent = readFile(srcFile)
    var lexer = newLexer(frContent)
    let tokens = lexer.tokenize()
    var parser = newParser(tokens)
    let ast = parser.parse()
    var codegen = newNimCodeGenerator()
    let nimContent = codegen.generate(ast)
    
    let baseName = file.changeFileExt("")
    let randomizedName = baseName & "_" & stdlibPrefix[4..^1] & ".nim"
    let destFile = tempDir / randomizedName
    writeFile(destFile, nimContent)

proc main() =
  let args = commandLineParams()
  
  if args.len == 0:
    echo "Usage: fr-transpiler <input.fr> [--compile|-c] [--target|-t <macos|windows|linux>]"
    quit(1)
  
  let inputFile = args[0]
  let targetPlatform = getTargetPlatform(args)
  
  if not fileExists(inputFile):
    echo "File not found: ", inputFile
    quit(1)
  
  try:
    let stdlibId = generateRandomId()
    let stdlibPrefix = "std_" & stdlibId
    var processedFiles: seq[string] = @[]
    let dependencyFiles = processImports(inputFile, processedFiles)
    let code = transpileFile(inputFile, stdlibPrefix)
    
    if "--compile" in args or "-c" in args:
      echo "Compiling with Nim for ", targetPlatform, "..."
      
      let tempDir = getTempDir() / "fr-transpile-" & stdlibId
      createDir(tempDir)
      let tempNimFile = tempDir / inputFile.extractFilename().changeFileExt(".nim")
      
      try:
        writeFile(tempNimFile, code)
        
        for depFile in dependencyFiles:
          let depNimCode = transpileFile(depFile, stdlibPrefix)
          let depName = depFile.extractFilename().changeFileExt(".nim")
          let depNimPath = tempDir / depName
          writeFile(depNimPath, depNimCode)
          echo "Transpiled dependency: ", depFile, " → ", depName
        
        copyStdlib(tempDir, stdlibPrefix)
        
        let compileCmd = getNimCompileCommand(targetPlatform, tempNimFile)
        let (output, exitCode) = execCmdEx(compileCmd)
        
        if exitCode != 0:
          echo "Compilation failed:"
          echo output
          removeDir(tempDir)
          quit(1)
        
        echo output
        
        let binaryName = tempNimFile.extractFilename().changeFileExt("")
        let extension = if targetPlatform == windows: ".exe" else: ""
        let tempBinary = tempDir / (binaryName & extension)
        let targetBinary = inputFile.parentDir() / (binaryName & extension)
        
        if fileExists(tempBinary):
          copyFile(tempBinary, targetBinary)
          echo "Binary compiled for ", targetPlatform, ": ", targetBinary
        else:
          echo "Binary created successfully in temp directory"
        
        removeDir(tempDir)
        echo "Compilation successful!"
        
      except:
        removeDir(tempDir)
        raise
    
    else:
      let outputFile = inputFile.changeFileExt(".nim")
      writeFile(outputFile, code)
      
      echo "Transpiled ", inputFile, " → ", outputFile
      
      for depFile in dependencyFiles:
        let depNimCode = transpileFile(depFile, stdlibPrefix)
        let depOutputFile = depFile.changeFileExt(".nim")
        writeFile(depOutputFile, depNimCode)
        echo "Transpiled dependency: ", depFile, " → ", depOutputFile
      
      let stdlibPath = outputFile.parentDir() / (stdlibPrefix & ".nim")
      if not fileExists(stdlibPath):
        copyStdlib(outputFile.parentDir(), stdlibPrefix)
        echo "Generated and copied standard library with randomized names"
  
  except Exception as e:
    echo "Error: ", e.msg
    quit(1)

when isMainModule:
  main()
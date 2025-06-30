#!/usr/bin/env node

import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { exec } from 'child_process';
import { Lexer } from './lexer';
import { Parser } from './parser';
import { NimCodeGenerator } from './codegen';
import { ImportDeclaration } from './types';
import * as crypto from 'crypto';

function processImports(inputFile: string, processedFiles: Set<string> = new Set()): string[] {
  const absolutePath = path.resolve(inputFile);
  
  if (processedFiles.has(absolutePath)) {
    return [];
  }
  processedFiles.add(absolutePath);
  
  const source = fs.readFileSync(inputFile, 'utf-8');
  const lexer = new Lexer(source);
  const tokens = lexer.tokenize();
  const parser = new Parser(tokens);
  const ast = parser.parse();
  
  const imports = ast.body.filter(node => node.type === 'ImportDeclaration') as ImportDeclaration[];
  const filesToProcess: string[] = [];
  
  for (const importNode of imports) {
    const importPath = path.resolve(path.dirname(inputFile), importNode.path);
    if (fs.existsSync(importPath)) {
      const subFiles = processImports(importPath, processedFiles);
      filesToProcess.push(...subFiles, importPath);
    }
  }
  
  return filesToProcess;
}

function transpileFile(inputFile: string, stdlibPrefix?: string, target: 'nim' = 'nim'): string {
  const source = fs.readFileSync(inputFile, 'utf-8');
  const lexer = new Lexer(source);
  const tokens = lexer.tokenize();
  const parser = new Parser(tokens);
  const ast = parser.parse();
  
  const codegen = new NimCodeGenerator(stdlibPrefix);
  return codegen.generate(ast);
}

function generateRandomId(): string {
  return crypto.randomBytes(8).toString('hex');
}

function getTargetPlatform(args: string[]): string {
  const targetIndex = args.findIndex(arg => arg === '--target' || arg === '-t');
  if (targetIndex !== -1 && targetIndex + 1 < args.length) {
    const target = args[targetIndex + 1].toLowerCase();
    if (['macos', 'windows', 'linux'].includes(target)) {
      return target;
    }
  }
  
  const platform = os.platform();
  switch (platform) {
    case 'darwin': return 'macos';
    case 'win32': return 'windows';
    case 'linux': return 'linux';
    default: return 'linux'; // fallback
  }
}

function getNimCompileCommand(target: string, nimFile: string): string {
  const baseCmd = `nim c`;
  
  switch (target) {
    case 'macos':
      return `${baseCmd} --os:macosx "${nimFile}"`;
    case 'windows':
      return `${baseCmd} --os:windows "${nimFile}"`;
    case 'linux':
      return `${baseCmd} --os:linux "${nimFile}"`;
    default:
      return `${baseCmd} "${nimFile}"`;
  }
}

function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: fr-transpiler <input.fr> [--compile|-c] [--target|-t <macos|windows|linux>] [--backend <nim|c>]');
    process.exit(1);
  }

  const inputFile = args[0];
  const targetPlatform = getTargetPlatform(args);
  
  if (!fs.existsSync(inputFile)) {
    console.error(`File not found: ${inputFile}`);
    process.exit(1);
  }

  try {
    const stdlibId = generateRandomId();
    const stdlibPrefix = `std_${stdlibId}`;
    const dependencyFiles = processImports(inputFile);
    const code = transpileFile(inputFile, stdlibPrefix);
    
    if (args.includes('--compile') || args.includes('-c')) {
      console.log(`Compiling with Nim for ${targetPlatform}...`);

      const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fr-transpile-'));
      const tempNimFile = path.join(tempDir, path.basename(inputFile).replace('.fr', '.nim'));
      const tempStdlibPath = path.join(tempDir, `${stdlibPrefix}.nim`);
      
      try {
        fs.writeFileSync(tempNimFile, code);
        
        for (const depFile of dependencyFiles) {
          const depNimCode = transpileFile(depFile, stdlibPrefix);
          const depName = path.basename(depFile).replace('.fr', '.nim');
          const depNimPath = path.join(tempDir, depName);
          fs.writeFileSync(depNimPath, depNimCode);
          console.log(`Transpiled dependency: ${depFile} → ${depName}`);
        }

        const stdlibSource = path.join(__dirname, 'stdlib');
        if (fs.existsSync(stdlibSource)) {
          const files = fs.readdirSync(stdlibSource);
          const nimFiles = files.filter(file => file.endsWith('.nim'));
          const frFiles = files.filter(file => file.endsWith('.fr'));
          
          let mainStdlibContent = '# Standard Library - Auto-generated\n\n';
          
          for (const file of nimFiles) {
            const baseName = path.basename(file, '.nim');
            mainStdlibContent += `include "./${baseName}_${stdlibId}"\n`;
          }
          
          for (const file of frFiles) {
            const baseName = path.basename(file, '.fr');
            mainStdlibContent += `include "./${baseName}_${stdlibId}"\n`;
          }
          
          const mainStdlibFile = path.join(tempDir, `${stdlibPrefix}.nim`);
          fs.writeFileSync(mainStdlibFile, mainStdlibContent);
          
          for (const file of nimFiles) {
            const srcFile = path.join(stdlibSource, file);
            const baseName = path.basename(file, '.nim');
            const randomizedName = `${baseName}_${stdlibId}.nim`;
            const destFile = path.join(tempDir, randomizedName);
            fs.copyFileSync(srcFile, destFile);
          }
          
          for (const file of frFiles) {
            const srcFile = path.join(stdlibSource, file);
            const frContent = fs.readFileSync(srcFile, 'utf-8');
            const lexer = new Lexer(frContent);
            const tokens = lexer.tokenize();
            const parser = new Parser(tokens);
            const ast = parser.parse();
            const codegen = new NimCodeGenerator();
            const nimContent = codegen.generate(ast);
            
            const baseName = path.basename(file, '.fr');
            const randomizedName = `${baseName}_${stdlibId}.nim`;
            const destFile = path.join(tempDir, randomizedName);
            fs.writeFileSync(destFile, nimContent);
          }
        }
        
        const compileCmd = getNimCompileCommand(targetPlatform, tempNimFile);
        exec(compileCmd, (error, stdout, stderr) => {
          if (error) {
            console.error('Compilation failed:', error.message);
            fs.rmSync(tempDir, { recursive: true, force: true });
            return;
          }
          if (stderr) {
            console.error('Nim warnings/errors:', stderr);
          }
          if (stdout) {
            console.log(stdout);
          }
          
          const binaryName = path.basename(tempNimFile, '.nim');
          const extension = targetPlatform === 'windows' ? '.exe' : '';
          const tempBinary = path.join(tempDir, binaryName + extension);
          const targetBinary = path.join(path.dirname(inputFile), binaryName + extension);
          
          if (fs.existsSync(tempBinary)) {
            fs.copyFileSync(tempBinary, targetBinary);
            console.log(`Binary compiled for ${targetPlatform}: ${targetBinary}`);
          } else {
            console.log('Binary created successfully in temp directory');
          }
          
          fs.rmSync(tempDir, { recursive: true, force: true });
          console.log('Compilation successful!');
        });
        
      } catch (compileError) {
        fs.rmSync(tempDir, { recursive: true, force: true });
        throw compileError;
      }
      
    } else {
      const outputFile = inputFile.replace('.fr', '.nim');
      fs.writeFileSync(outputFile, code);
      
      console.log(`Transpiled ${inputFile} → ${outputFile}`);
      
      for (const depFile of dependencyFiles) {
        const depNimCode = transpileFile(depFile, stdlibPrefix);
        const depOutputFile = depFile.replace('.fr', '.nim');
        fs.writeFileSync(depOutputFile, depNimCode);
        console.log(`Transpiled dependency: ${depFile} → ${depOutputFile}`);
      }
      
      const stdlibPath = path.join(path.dirname(outputFile), `${stdlibPrefix}.nim`);
      if (!fs.existsSync(stdlibPath)) {
        const stdlibSource = path.join(__dirname, 'stdlib');
        if (fs.existsSync(stdlibSource)) {
          const files = fs.readdirSync(stdlibSource);
          const nimFiles = files.filter(file => file.endsWith('.nim'));
          const frFiles = files.filter(file => file.endsWith('.fr'));
          
          let mainStdlibContent = '# Standard Library - Auto-generated\n\n';
          
          for (const file of nimFiles) {
            const baseName = path.basename(file, '.nim');
            mainStdlibContent += `include "./${baseName}_${stdlibId}"\n`;
          }
          
          for (const file of frFiles) {
            const baseName = path.basename(file, '.fr');
            mainStdlibContent += `include "./${baseName}_${stdlibId}"\n`;
          }
          
          const mainStdlibFile = path.join(path.dirname(outputFile), `${stdlibPrefix}.nim`);
          fs.writeFileSync(mainStdlibFile, mainStdlibContent);
          
          for (const file of nimFiles) {
            const srcFile = path.join(stdlibSource, file);
            const baseName = path.basename(file, '.nim');
            const randomizedName = `${baseName}_${stdlibId}.nim`;
            const destFile = path.join(path.dirname(outputFile), randomizedName);
            fs.copyFileSync(srcFile, destFile);
          }
          
          for (const file of frFiles) {
            const srcFile = path.join(stdlibSource, file);
            const frContent = fs.readFileSync(srcFile, 'utf-8');
            const lexer = new Lexer(frContent);
            const tokens = lexer.tokenize();
            const parser = new Parser(tokens);
            const ast = parser.parse();
            const codegen = new NimCodeGenerator();
            const nimContent = codegen.generate(ast);
            
            const baseName = path.basename(file, '.fr');
            const randomizedName = `${baseName}_${stdlibId}.nim`;
            const destFile = path.join(path.dirname(outputFile), randomizedName);
            fs.writeFileSync(destFile, nimContent);
          }
          
          console.log('Generated and copied standard library with randomized names');
        }
      }
    }
    
  } catch (error) {
    console.error('Error:', error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmShowcaseDUnitXTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  NativeAsm.Tests.Crc32C in 'DUnitX\NativeAsm.Tests.Crc32C.pas',
  NativeAsm.Tests.HashProbe in 'DUnitX\NativeAsm.Tests.HashProbe.pas',
  NativeAsm.Tests.Bitset in 'DUnitX\NativeAsm.Tests.Bitset.pas',
  NativeAsm.Tests.Memory in 'DUnitX\NativeAsm.Tests.Memory.pas',
  NativeAsm.Tests.Hex in 'DUnitX\NativeAsm.Tests.Hex.pas',
  NativeAsm.Tests.Base64 in 'DUnitX\NativeAsm.Tests.Base64.pas',
  NativeAsm.Tests.Hash64 in 'DUnitX\NativeAsm.Tests.Hash64.pas',
  NativeAsm.Tests.BloomFilter in 'DUnitX\NativeAsm.Tests.BloomFilter.pas',
  NativeAsm.Tests.Strings in 'DUnitX\NativeAsm.Tests.Strings.pas',
  NativeAsm.Tests.Crc32 in 'DUnitX\NativeAsm.Tests.Crc32.pas',
  NativeAsm.Tests.ChaCha20 in 'DUnitX\NativeAsm.Tests.ChaCha20.pas',
  NativeAsm.Tests.Poly1305 in 'DUnitX\NativeAsm.Tests.Poly1305.pas',
  NativeAsm.Tests.ChaCha20Poly1305 in 'DUnitX\NativeAsm.Tests.ChaCha20Poly1305.pas',
  NativeAsm.Tests.Blake3 in 'DUnitX\NativeAsm.Tests.Blake3.pas',
  NativeAsm.Tests.Xoshiro256pp in 'DUnitX\NativeAsm.Tests.Xoshiro256pp.pas',
  NativeAsm.Tests.BigInt in 'DUnitX\NativeAsm.Tests.BigInt.pas',
  NativeAsm.Tests.Field25519 in 'DUnitX\NativeAsm.Tests.Field25519.pas',
  NativeAsm.Tests.Secp256k1 in 'DUnitX\NativeAsm.Tests.Secp256k1.pas',
  NativeAsm.Tests.P256 in 'DUnitX\NativeAsm.Tests.P256.pas',
  NativeAsm.Tests.Ed25519 in 'DUnitX\NativeAsm.Tests.Ed25519.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
begin
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := True;
    if TDUnitX.Options.ConsoleMode <> TDUnitXConsoleMode.Off then
    begin
      Logger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDUnitXConsoleMode.Quiet);
      Runner.AddLogger(Logger);
    end;
    Results := Runner.Execute;
    if not Results.AllPassed then System.ExitCode := 1;
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 1;
    end;
  end;
end.

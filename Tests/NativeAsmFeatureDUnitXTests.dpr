{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmFeatureDUnitXTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  NativeAsm.Tests.AlignmentRules in 'DUnitX\NativeAsm.Tests.AlignmentRules.pas',
  NativeAsm.Tests.CpuFeatures in 'DUnitX\NativeAsm.Tests.CpuFeatures.pas',
  NativeAsm.Tests.AbiWin64 in 'DUnitX\NativeAsm.Tests.AbiWin64.pas',
  NativeAsm.Tests.Levenshtein in 'DUnitX\NativeAsm.Tests.Levenshtein.pas',
  NativeAsm.Tests.AhoCorasick in 'DUnitX\NativeAsm.Tests.AhoCorasick.pas',
  NativeAsm.Practical.AhoCorasick in 'Practical\NativeAsm.Practical.AhoCorasick.pas',
  NativeAsm.Tests.Pclmul in 'DUnitX\NativeAsm.Tests.Pclmul.pas',
  NativeAsm.Tests.GpCarryMul in 'DUnitX\NativeAsm.Tests.GpCarryMul.pas';

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

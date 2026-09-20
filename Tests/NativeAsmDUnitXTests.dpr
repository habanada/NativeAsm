{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
{ Test design and vectors adapted from AsmJit. See Tests/ASMJIT_TEST_SOURCE.md. }program NativeAsmDUnitXTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  NativeAsm.Tests.AsmJit in 'DUnitX\NativeAsm.Tests.AsmJit.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
begin
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := False;
    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);
    Results := Runner.Execute;
    if not Results.AllPassed then ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

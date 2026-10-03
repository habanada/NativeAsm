program NativeAsmAvx2ClosureDUnitXTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  NativeAsm.Avx2.Tests.Support in 'DUnitX\NativeAsm.Avx2.Tests.Support.pas',
  NativeAsm.Avx2.Tests.Database in 'DUnitX\NativeAsm.Avx2.Tests.Database.pas',
  NativeAsm.Avx2.Tests.Golden in 'DUnitX\NativeAsm.Avx2.Tests.Golden.pas',
  NativeAsm.Avx2.Tests.Semantics in 'DUnitX\NativeAsm.Avx2.Tests.Semantics.pas',
  NativeAsm.Avx2.Tests.MixedIntegration in 'DUnitX\NativeAsm.Avx2.Tests.MixedIntegration.pas';

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

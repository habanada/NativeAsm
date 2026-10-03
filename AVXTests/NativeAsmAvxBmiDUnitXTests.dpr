program NativeAsmAvxBmiDUnitXTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  NativeAsm.Tests.SimdSupport in 'DUnitX\NativeAsm.Tests.SimdSupport.pas',
  NativeAsm.Tests.AvxBmiDatabase in 'DUnitX\NativeAsm.Tests.AvxBmiDatabase.pas',
  NativeAsm.Tests.AvxBmiEncoding in 'DUnitX\NativeAsm.Tests.AvxBmiEncoding.pas',
  NativeAsm.Tests.AvxBmiValidation in 'DUnitX\NativeAsm.Tests.AvxBmiValidation.pas',
  NativeAsm.Tests.AvxBmiStress in 'DUnitX\NativeAsm.Tests.AvxBmiStress.pas',
  NativeAsm.Tests.AvxBmiRuntime in 'DUnitX\NativeAsm.Tests.AvxBmiRuntime.pas';

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

program NativeAsmAvxShowcaseDUnitXTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  NativeAsm.AvxShowcase.Types in '..\NativeAsm.AvxShowcase.Types.pas',
  NativeAsm.AvxShowcase.Fft in '..\NativeAsm.AvxShowcase.Fft.pas',
  NativeAsm.AvxShowcase.Transpose in '..\NativeAsm.AvxShowcase.Transpose.pas',
  NativeAsm.AvxShowcase.Mandelbrot in '..\NativeAsm.AvxShowcase.Mandelbrot.pas',
  NativeAsm.AvxShowcase.Polynomial in '..\NativeAsm.AvxShowcase.Polynomial.pas',
  NativeAsm.AvxShowcase.FloatEdgeCases in '..\NativeAsm.AvxShowcase.FloatEdgeCases.pas',
  NativeAsm.AvxShowcase.FaceDetection in '..\NativeAsm.AvxShowcase.FaceDetection.pas',
  NativeAsm.AvxShowcase.Tests in 'DUnitX\NativeAsm.AvxShowcase.Tests.pas';

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
    if not Results.AllPassed then ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

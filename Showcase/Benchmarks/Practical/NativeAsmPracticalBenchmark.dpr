{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmPracticalBenchmark;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  NativeAsm.Benchmark.Common in 'NativeAsm.Benchmark.Common.pas',
  NativeAsm.Benchmark.SelfTest in 'NativeAsm.Benchmark.SelfTest.pas',
  NativeAsm.Benchmark.Cases in 'NativeAsm.Benchmark.Cases.pas';

begin
  try
    InitBenchmark;
    ParseArgs;
    PrintBanner;
    if not GConfig.SkipSelfTest then RunNativeAsmSelfTests;
    if not GConfig.SelfTestOnly then RunAllBenchmarks;
    if GConfig.CsvPath <> '' then
    begin
      WriteCsv(GConfig.CsvPath);
      Writeln;
      Writeln('CSV: ', GConfig.CsvPath);
    end;
    Writeln;
    Writeln('sink=', IntToHex(GSink, 16));
  except
    on E: Exception do
    begin
      Writeln;
      Writeln('ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmSelfTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  NativeAsm.Benchmark.SelfTest in 'NativeAsm.Benchmark.SelfTest.pas';

begin
  try
    RunNativeAsmSelfTests;
  except
    on E: Exception do
    begin
      Writeln;
      Writeln('ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

program NativeAsmPracticalBenchmark;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  NativeAsm.Algorithms.Levenshtein in '..\Tests\NativeAsm.Algorithms.Levenshtein.pas',
  NativeAsm.Practical.AhoCorasick in '..\Tests\Practical\NativeAsm.Practical.AhoCorasick.pas',
  NativeAsm.Practical.Benchmarks in 'NativeAsm.Practical.Benchmarks.pas';

begin
  try
    RunPracticalBenchmarks;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

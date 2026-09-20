unit NativeAsm.Practical.Benchmarks;

interface

procedure RunPracticalBenchmarks;

implementation

uses
  System.SysUtils,
  System.Diagnostics,
  NativeAsm.Algorithms.Levenshtein,
  NativeAsm.Practical.AhoCorasick;

type
  TBenchProc = reference to procedure(Iterations: Integer);

  TBenchConfig = record
    TargetMs: Integer;
    Samples: Integer;
    Quick: Boolean;
  end;

  TLevenshteinReference = class
  private
    FRow: TArray<Cardinal>;
    procedure EnsureRow(ALength: Integer);
  public
    function Distance(const A, B: string): Cardinal;
    function FindBest(const Needle: string; const Candidates: TArray<string>; out Distance: Cardinal): Integer;
  end;

var
  GConfig: TBenchConfig;
  GSink: UInt64;

function MeasureMs(const Proc: TBenchProc; Iterations: Integer): Double;
var
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  Proc(Iterations);
  SW.Stop;
  Result := SW.Elapsed.TotalMilliseconds;
end;

function Calibrate(const Proc: TBenchProc): Integer;
var
  Iterations, NextIterations, Attempt: Integer;
  Elapsed, Ratio: Double;
begin
  Iterations := 1;
  for Attempt := 1 to 10 do
  begin
    Elapsed := MeasureMs(Proc, Iterations);
    if Elapsed >= GConfig.TargetMs * 0.8 then Break;
    if Elapsed <= 0 then NextIterations := Iterations * 8
    else
    begin
      Ratio := GConfig.TargetMs / Elapsed;
      if Ratio > 8 then Ratio := 8;
      if Ratio < 1.25 then Ratio := 1.25;
      NextIterations := Trunc(Iterations * Ratio);
    end;
    if NextIterations <= Iterations then Inc(NextIterations);
    if NextIterations > 1000000 then NextIterations := 1000000;
    Iterations := NextIterations;
  end;
  Result := Iterations;
end;

procedure SortDoubles(var Values: TArray<Double>);
var
  I, J: Integer;
  V: Double;
begin
  for I := 1 to High(Values) do
  begin
    V := Values[I];
    J := I - 1;
    while (J >= 0) and (Values[J] > V) do
    begin
      Values[J + 1] := Values[J];
      Dec(J);
    end;
    Values[J + 1] := V;
  end;
end;

function Median(const Values: TArray<Double>): Double;
var
  N: Integer;
begin
  N := Length(Values);
  if Odd(N) then Result := Values[N div 2] else Result := (Values[N div 2 - 1] + Values[N div 2]) * 0.5;
end;

function RunCase(const Name, UnitName: string; UnitsPerIteration: Double; const Proc: TBenchProc): Double;
var
  Samples: TArray<Double>;
  Iterations, I: Integer;
  MedianMs, Throughput: Double;
begin
  Proc(1);
  Iterations := Calibrate(Proc);
  SetLength(Samples, GConfig.Samples);
  for I := 0 to High(Samples) do Samples[I] := MeasureMs(Proc, Iterations) / Iterations;
  SortDoubles(Samples);
  MedianMs := Median(Samples);
  if MedianMs > 0 then Throughput := UnitsPerIteration / (MedianMs / 1000) else Throughput := 0;
  Writeln(Format('%-34s %10d %12.3f %14.2f %s/s', [Name, Iterations, MedianMs, Throughput, UnitName]));
  Result := MedianMs;
end;

function MakePattern(Index, Len: Integer): string;
var
  I: Integer;
begin
  SetLength(Result, Len);
  Result[1] := Char(Ord('A') + Index);
  for I := 2 to Len do Result[I] := Char(Ord('a') + ((Index * 11 + I * 7) mod 26));
end;

function MakeAhoText(CharCount: Integer; const Patterns: TArray<string>): string;
var
  I, P, Pos1: Integer;
begin
  SetLength(Result, CharCount);
  for I := 1 to CharCount do Result[I] := Char(Ord('k') + ((I * 13 + I div 17) mod 10));
  Pos1 := 2048;
  P := 0;
  while Pos1 + Length(Patterns[P]) <= CharCount do
  begin
    Move(PChar(Patterns[P])^, Result[Pos1], Length(Patterns[P]) * SizeOf(Char));
    Inc(P);
    if P = Length(Patterns) then P := 0;
    Inc(Pos1, 65521);
  end;
end;

function SimdName(Mode: TAhoSimdMode): string;
begin
  case Mode of
    smScalar: Result := 'scalar';
    smSse2: Result := 'sse2';
    smSse42: Result := 'sse4.2';
  else
    Result := 'auto';
  end;
end;

procedure BenchmarkAhoSize(CharCount: Integer; const Patterns: TArray<string>; Scalar, Sse2, Sse42, Auto: TAhoCorasickJit);
var
  Text: string;
  Expected: UInt64;
  SizeMiB, ScalarMs, Sse2Ms, Sse42Ms, AutoMs: Double;
  LabelText: string;
begin
  Text := MakeAhoText(CharCount, Patterns);
  SizeMiB := Length(Text) * SizeOf(Char) / (1024.0 * 1024.0);
  LabelText := FormatFloat('0.0', SizeMiB) + ' MiB';
  Expected := Scalar.CountMatches(Text);
  if Sse2.CountMatches(Text) <> Expected then raise EInvalidOp.Create('Aho SSE2 result differs from scalar');
  if (Sse42 <> nil) and (Sse42.CountMatches(Text) <> Expected) then raise EInvalidOp.Create('Aho SSE4.2 result differs from scalar');
  if Auto.CountMatches(Text) <> Expected then raise EInvalidOp.Create('Aho auto result differs from scalar');

  Writeln;
  Writeln('Aho-Corasick ', LabelText, '  matches=', Expected, '  auto=', SimdName(Auto.SimdMode));
  ScalarMs := RunCase('Aho scalar ' + LabelText, 'MiB', SizeMiB, procedure(Iterations: Integer) var I: Integer; V: UInt64; begin V := 0; for I := 1 to Iterations do V := V xor Scalar.CountMatches(Text); GSink := GSink xor V; end);
  Sse2Ms := RunCase('Aho SSE2 ' + LabelText, 'MiB', SizeMiB, procedure(Iterations: Integer) var I: Integer; V: UInt64; begin V := 0; for I := 1 to Iterations do V := V xor Sse2.CountMatches(Text); GSink := GSink xor V; end);
  Sse42Ms := 0;
  if Sse42 <> nil then Sse42Ms := RunCase('Aho SSE4.2 ' + LabelText, 'MiB', SizeMiB, procedure(Iterations: Integer) var I: Integer; V: UInt64; begin V := 0; for I := 1 to Iterations do V := V xor Sse42.CountMatches(Text); GSink := GSink xor V; end);
  AutoMs := RunCase('Aho auto ' + LabelText, 'MiB', SizeMiB, procedure(Iterations: Integer) var I: Integer; V: UInt64; begin V := 0; for I := 1 to Iterations do V := V xor Auto.CountMatches(Text); GSink := GSink xor V; end);
  Writeln('  speedup SSE2=', FormatFloat('0.00x', ScalarMs / Sse2Ms), '  auto=', FormatFloat('0.00x', ScalarMs / AutoMs));
  if Sse42Ms > 0 then Writeln('  speedup SSE4.2=', FormatFloat('0.00x', ScalarMs / Sse42Ms));
end;

procedure BenchmarkAho;
var
  Patterns: TArray<string>;
  Scalar, Sse2, Sse42, Auto: TAhoCorasickJit;
  I: Integer;
  SW: TStopwatch;
begin
  SetLength(Patterns, 10);
  for I := 0 to High(Patterns) do Patterns[I] := MakePattern(I, 48);
  Writeln;
  Writeln('=== Aho-Corasick reusable JIT ===');
  SW := TStopwatch.StartNew;
  Scalar := TAhoCorasickJit.Create(Patterns, smScalar);
  Sse2 := TAhoCorasickJit.Create(Patterns, smSse2);
  if TAhoCorasickJit.IsSse42Available then Sse42 := TAhoCorasickJit.Create(Patterns, smSse42) else Sse42 := nil;
  Auto := TAhoCorasickJit.Create(Patterns, smAuto);
  SW.Stop;
  try
    Writeln('setup all modes=', FormatFloat('0.000', SW.Elapsed.TotalMilliseconds), ' ms  auto=', SimdName(Auto.SimdMode));
    BenchmarkAhoSize(512 * 1024, Patterns, Scalar, Sse2, Sse42, Auto);
    BenchmarkAhoSize(4 * 1024 * 1024, Patterns, Scalar, Sse2, Sse42, Auto);
    if not GConfig.Quick then BenchmarkAhoSize(16 * 1024 * 1024, Patterns, Scalar, Sse2, Sse42, Auto);
  finally
    Auto.Free;
    Sse42.Free;
    Sse2.Free;
    Scalar.Free;
  end;
end;

function MakeLevenshteinBase(Len: Integer): string;
var
  I: Integer;
begin
  SetLength(Result, Len);
  for I := 1 to Len do Result[I] := Char(Ord('a') + ((I * 17 + I div 11) mod 26));
end;

function MutateLevenshtein(const S: string; Candidate: Integer): string;
var
  I, P, Changes: Integer;
begin
  Result := S;
  if Result = '' then Exit;
  if Result[1] = 'Z' then Result[1] := 'Y' else Result[1] := 'Z';
  if Length(Result) > 1 then if Result[Length(Result)] = 'Q' then Result[Length(Result)] := 'R' else Result[Length(Result)] := 'Q';
  Changes := 3 + Candidate;
  for I := 0 to Changes - 1 do
  begin
    P := 1 + ((Candidate * 131 + I * 977) mod Length(Result));
    if Result[P] = 'X' then Result[P] := 'W' else Result[P] := 'X';
  end;
end;

procedure TLevenshteinReference.EnsureRow(ALength: Integer);
begin
  if Length(FRow) < ALength then SetLength(FRow, ALength);
end;

function TLevenshteinReference.Distance(const A, B: string): Cardinal;
var
  PA, PB, PTemp: PChar;
  LA, LB, LTemp, I, J: Integer;
  Prev, Old, V, Candidate: Cardinal;
begin
  LA := Length(A);
  LB := Length(B);
  if LA = 0 then Exit(Cardinal(LB));
  if LB = 0 then Exit(Cardinal(LA));
  PA := PChar(A);
  PB := PChar(B);
  while (LA > 0) and (LB > 0) and (PA^ = PB^) do
  begin
    Inc(PA);
    Inc(PB);
    Dec(LA);
    Dec(LB);
  end;
  while (LA > 0) and (LB > 0) and (PA[LA - 1] = PB[LB - 1]) do
  begin
    Dec(LA);
    Dec(LB);
  end;
  if LA = 0 then Exit(Cardinal(LB));
  if LB = 0 then Exit(Cardinal(LA));
  if LA > LB then
  begin
    PTemp := PA;
    PA := PB;
    PB := PTemp;
    LTemp := LA;
    LA := LB;
    LB := LTemp;
  end;
  EnsureRow(LA + 1);
  for I := 0 to LA do FRow[I] := Cardinal(I);
  for J := 1 to LB do
  begin
    Prev := FRow[0];
    FRow[0] := Cardinal(J);
    for I := 1 to LA do
    begin
      Old := FRow[I];
      if PA[I - 1] = PB[J - 1] then V := Prev else V := Prev + 1;
      Candidate := Old + 1;
      if Candidate < V then V := Candidate;
      Candidate := FRow[I - 1] + 1;
      if Candidate < V then V := Candidate;
      FRow[I] := V;
      Prev := Old;
    end;
  end;
  Result := FRow[LA];
end;

function TLevenshteinReference.FindBest(const Needle: string; const Candidates: TArray<string>; out Distance: Cardinal): Integer;
var
  I: Integer;
  D: Cardinal;
begin
  Result := -1;
  Distance := High(Cardinal);
  for I := 0 to High(Candidates) do
  begin
    D := Self.Distance(Needle, Candidates[I]);
    if D < Distance then
    begin
      Distance := D;
      Result := I;
      if D = 0 then Exit;
    end;
  end;
end;

procedure BenchmarkLevenshteinSize(Len: Integer; Jit: TLevenshteinJit; Ref: TLevenshteinReference);
var
  Needle: string;
  Candidates: TArray<string>;
  I, JitIndex, RefIndex: Integer;
  JitDistance, RefDistance: Cardinal;
  CellsM, JitMs, RefMs: Double;
  LabelText: string;
begin
  Needle := MakeLevenshteinBase(Len);
  SetLength(Candidates, 10);
  for I := 0 to High(Candidates) do Candidates[I] := MutateLevenshtein(Needle, I);
  JitIndex := Jit.FindBest(Needle, Candidates, JitDistance);
  RefIndex := Ref.FindBest(Needle, Candidates, RefDistance);
  if (JitIndex <> RefIndex) or (JitDistance <> RefDistance) then raise EInvalidOp.Create('Levenshtein JIT result differs from reference');
  for I := 0 to High(Candidates) do if Jit.Distance(Needle, Candidates[I]) <> Ref.Distance(Needle, Candidates[I]) then raise EInvalidOp.CreateFmt('Levenshtein candidate %d differs from reference', [I]);

  CellsM := (Int64(Len) * Int64(Len) * Length(Candidates)) / 1000000.0;
  LabelText := Format('10x%d', [Len]);
  Writeln;
  Writeln('Levenshtein ', LabelText, '  best=', JitIndex, '  distance=', JitDistance, '  nominal=', FormatFloat('0.0', CellsM), ' MCells');
  JitMs := RunCase('Levenshtein JIT ' + LabelText, 'MCells', CellsM, procedure(Iterations: Integer) var N, Index: Integer; D: Cardinal; begin Index := 0; D := 0; for N := 1 to Iterations do Index := Jit.FindBest(Needle, Candidates, D); GSink := GSink xor UInt64(Cardinal(Index + 1)) xor D; end);
  RefMs := RunCase('Levenshtein Delphi ' + LabelText, 'MCells', CellsM, procedure(Iterations: Integer) var N, Index: Integer; D: Cardinal; begin Index := 0; D := 0; for N := 1 to Iterations do Index := Ref.FindBest(Needle, Candidates, D); GSink := GSink xor UInt64(Cardinal(Index + 1)) xor D; end);
  Writeln('  speedup JIT=', FormatFloat('0.00x', RefMs / JitMs));
end;

procedure BenchmarkLevenshtein;
var
  Jit: TLevenshteinJit;
  Ref: TLevenshteinReference;
  SW: TStopwatch;
begin
  Writeln;
  Writeln('=== Levenshtein reusable JIT ===');
  SW := TStopwatch.StartNew;
  Jit := TLevenshteinJit.Create;
  SW.Stop;
  Ref := TLevenshteinReference.Create;
  try
    Writeln('JIT setup=', FormatFloat('0.000', SW.Elapsed.TotalMilliseconds), ' ms');
    BenchmarkLevenshteinSize(256, Jit, Ref);
    BenchmarkLevenshteinSize(1024, Jit, Ref);
    if not GConfig.Quick then BenchmarkLevenshteinSize(2048, Jit, Ref);
  finally
    Ref.Free;
    Jit.Free;
  end;
end;

procedure ParseArgs;
var
  I: Integer;
begin
  GConfig.TargetMs := 250;
  GConfig.Samples := 7;
  GConfig.Quick := False;
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), '--quick') then
    begin
      GConfig.TargetMs := 80;
      GConfig.Samples := 3;
      GConfig.Quick := True;
    end;
end;

procedure RunPracticalBenchmarks;
begin
  ParseArgs;
  Writeln('NativeAsm Practical Benchmark');
  if GConfig.Quick then Writeln('mode=quick target=', GConfig.TargetMs, 'ms samples=', GConfig.Samples) else Writeln('mode=full target=', GConfig.TargetMs, 'ms samples=', GConfig.Samples);
  Writeln(Format('%-34s %10s %12s %18s', ['case', 'iterations', 'median/op', 'throughput']));
  BenchmarkAho;
  BenchmarkLevenshtein;
  Writeln;
  Writeln('sink=', GSink);
end;

end.

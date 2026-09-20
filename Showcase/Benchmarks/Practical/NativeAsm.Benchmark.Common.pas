{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Benchmark.Common;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  Winapi.Windows,
  NativeAsm.CpuFeatures;

type
  TBenchProc = reference to procedure(Iterations: Int64);
  TThroughputKind = (tkBytes, tkOperations, tkValues);

  TBenchConfig = record
    ModeName: string;
    TargetMs: Integer;
    WarmupMs: Integer;
    Samples: Integer;
    CsvPath: string;
    GroupName: string;
    SelfTestOnly: Boolean;
    SkipSelfTest: Boolean;
  end;

  TBenchResult = record
    SectionName: string;
    Name: string;
    UnitName: string;
    Iterations: Int64;
    UnitsPerOp: Int64;
    Samples: Integer;
    MedianNs: Double;
    MinNs: Double;
    MaxNs: Double;
    MeanNs: Double;
    RsdPct: Double;
    Throughput: Double;
    ThroughputUnit: string;
  end;

var
  GConfig: TBenchConfig;
  GFrequency: Int64;
  GSink: UInt64;
  GResults: array of TBenchResult;

procedure InitBenchmark;
procedure ParseArgs;
procedure PrintBanner;
procedure PrintSection(const Name: string);
function GroupEnabled(const Name: string): Boolean;
function NowTicks: Int64; inline;
function TicksToNs(Ticks: Int64): Double; inline;
function RunBenchmark(const SectionName, Name, UnitName: string; UnitsPerOp: Int64; Kind: TThroughputKind; const Proc: TBenchProc): TBenchResult;
procedure WriteCsv(const FileName: string);
function FormatBytes(Bytes: NativeUInt): string;
function FormatDuration(Ns: Double): string;
procedure Sink(Value: UInt64); inline;

implementation

function NowTicks: Int64;
begin
  QueryPerformanceCounter(Result);
end;

function TicksToNs(Ticks: Int64): Double;
begin
  Result := Ticks * (1000000000.0 / GFrequency);
end;

procedure Sink(Value: UInt64);
begin
  GSink := GSink xor Value;
end;

procedure InitBenchmark;
begin
  if not QueryPerformanceFrequency(GFrequency) then raise Exception.Create('QueryPerformanceFrequency failed');
  GSink := 0;
  SetLength(GResults, 0);
  GConfig.ModeName := 'full';
  GConfig.TargetMs := 250;
  GConfig.WarmupMs := 100;
  GConfig.Samples := 7;
  GConfig.CsvPath := '';
  GConfig.GroupName := 'all';
  GConfig.SelfTestOnly := False;
  GConfig.SkipSelfTest := False;
end;

procedure ParseArgs;
var
  I, V: Integer;
  S, Value: string;
begin
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    if SameText(S, '--quick') then
    begin
      GConfig.ModeName := 'quick';
      GConfig.TargetMs := 60;
      GConfig.WarmupMs := 30;
      GConfig.Samples := 5;
    end
    else if SameText(S, '--full') then
    begin
      GConfig.ModeName := 'full';
      GConfig.TargetMs := 250;
      GConfig.WarmupMs := 100;
      GConfig.Samples := 7;
    end
    else if Pos('--target-ms=', LowerCase(S)) = 1 then
    begin
      Value := Copy(S, Length('--target-ms=') + 1, MaxInt);
      if not TryStrToInt(Value, V) or (V < 10) then raise EArgumentException.Create('invalid --target-ms');
      GConfig.TargetMs := V;
      GConfig.ModeName := 'custom';
    end
    else if Pos('--warmup-ms=', LowerCase(S)) = 1 then
    begin
      Value := Copy(S, Length('--warmup-ms=') + 1, MaxInt);
      if not TryStrToInt(Value, V) or (V < 0) then raise EArgumentException.Create('invalid --warmup-ms');
      GConfig.WarmupMs := V;
      GConfig.ModeName := 'custom';
    end
    else if Pos('--samples=', LowerCase(S)) = 1 then
    begin
      Value := Copy(S, Length('--samples=') + 1, MaxInt);
      if not TryStrToInt(Value, V) or (V < 3) then raise EArgumentException.Create('invalid --samples');
      GConfig.Samples := V;
      GConfig.ModeName := 'custom';
    end
    else if Pos('--csv=', LowerCase(S)) = 1 then GConfig.CsvPath := Copy(S, Length('--csv=') + 1, MaxInt)
    else if Pos('--group=', LowerCase(S)) = 1 then GConfig.GroupName := LowerCase(Copy(S, Length('--group=') + 1, MaxInt))
    else if SameText(S, '--selftest-only') then GConfig.SelfTestOnly := True
    else if SameText(S, '--skip-selftest') then GConfig.SkipSelfTest := True
    else if SameText(S, '--help') or SameText(S, '-h') then
    begin
      Writeln('NativeAsmPracticalBenchmark [--quick|--full] [--target-ms=N] [--warmup-ms=N] [--samples=N] [--csv=file] [--group=all|crc|hash|crypto|codec|bloom|prng|bigint] [--selftest-only|--skip-selftest]');
      Halt(0);
    end
    else raise EArgumentException.CreateFmt('unknown argument: %s', [S]);
  end;
  if GConfig.SelfTestOnly and GConfig.SkipSelfTest then raise EArgumentException.Create('--selftest-only and --skip-selftest cannot be combined');
end;

procedure PrintBanner;
var
  SI: TSystemInfo;
begin
  GetSystemInfo(SI);
  Writeln('NativeAsm Practical Benchmark Suite');
  Writeln;
  Writeln(Format('mode=%s target=%dms warmup=%dms samples=%d group=%s', [GConfig.ModeName, GConfig.TargetMs, GConfig.WarmupMs, GConfig.Samples, GConfig.GroupName]));
  Writeln('cpu=', GetEnvironmentVariable('PROCESSOR_IDENTIFIER'));
  Writeln(Format('logical=%d process=%d-bit compiler=%.1f qpc=%dHz', [SI.dwNumberOfProcessors, SizeOf(Pointer) * 8, CompilerVersion, GFrequency]));
  Writeln(Format('features sse2=%d ssse3=%d sse4.2=%d pclmul=%d popcnt=%d bmi1=%d', [Ord(TCpuFeatures.Supports(cfSSE2)), Ord(TCpuFeatures.Supports(cfSSSE3)), Ord(TCpuFeatures.Supports(cfSSE42)), Ord(TCpuFeatures.Supports(cfPCLMULQDQ)), Ord(TCpuFeatures.Supports(cfPOPCNT)), Ord(TCpuFeatures.Supports(cfBMI1))]));
  Writeln;
end;

procedure PrintSection(const Name: string);
begin
  Writeln;
  Writeln('=== ', Name, ' ===');
  Writeln(Format('%-42s %10s %14s %16s %8s', ['case', 'iterations', 'median/op', 'throughput', 'RSD%']));
end;

function GroupEnabled(const Name: string): Boolean;
var
  G, N: string;
begin
  G := ',' + StringReplace(LowerCase(GConfig.GroupName), ' ', '', [rfReplaceAll]) + ',';
  N := LowerCase(Name);
  Result := (G = ',all,') or (Pos(',' + N + ',', G) <> 0);
end;

function MeasureNs(const Proc: TBenchProc; Iterations: Int64): Double;
var
  T0, T1: Int64;
begin
  T0 := NowTicks;
  Proc(Iterations);
  T1 := NowTicks;
  Result := TicksToNs(T1 - T0);
end;

function Calibrate(const Proc: TBenchProc): Int64;
var
  Iterations, NextIterations: Int64;
  ElapsedNs, TargetNs, Ratio: Double;
  Attempt: Integer;
begin
  TargetNs := GConfig.TargetMs * 1000000.0;
  Iterations := 1;
  for Attempt := 1 to 14 do
  begin
    ElapsedNs := MeasureNs(Proc, Iterations);
    if ElapsedNs >= TargetNs * 0.85 then Break;
    if ElapsedNs <= 0 then NextIterations := Iterations * 10
    else
    begin
      Ratio := TargetNs / ElapsedNs;
      if Ratio > 10 then Ratio := 10;
      if Ratio < 1.25 then Ratio := 1.25;
      NextIterations := Trunc(Iterations * Ratio);
    end;
    if NextIterations <= Iterations then NextIterations := Iterations + 1;
    if NextIterations > 1000000000 then NextIterations := 1000000000;
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

function MedianOf(const Sorted: TArray<Double>): Double;
var
  N: Integer;
begin
  N := Length(Sorted);
  if Odd(N) then Result := Sorted[N div 2] else Result := (Sorted[N div 2 - 1] + Sorted[N div 2]) * 0.5;
end;

function FormatDuration(Ns: Double): string;
begin
  if Ns < 1000 then Result := Format('%.1f ns', [Ns])
  else if Ns < 1000000 then Result := Format('%.3f us', [Ns / 1000.0])
  else Result := Format('%.3f ms', [Ns / 1000000.0]);
end;

function FormatBytes(Bytes: NativeUInt): string;
begin
  if Bytes >= NativeUInt(1024 * 1024) then Result := Format('%.1f MiB', [Bytes / 1048576.0])
  else if Bytes >= 1024 then Result := Format('%.1f KiB', [Bytes / 1024.0])
  else Result := IntToStr(Bytes) + ' B';
end;

function RunBenchmark(const SectionName, Name, UnitName: string; UnitsPerOp: Int64; Kind: TThroughputKind; const Proc: TBenchProc): TBenchResult;
var
  Samples, Sorted: TArray<Double>;
  Iterations, WarmupIterations: Int64;
  I, N: Integer;
  Sum, Variance, D, UnitsPerSecond: Double;
begin
  if UnitsPerOp <= 0 then raise EArgumentOutOfRangeException.Create('UnitsPerOp');
  Iterations := Calibrate(Proc);
  if GConfig.WarmupMs > 0 then
  begin
    WarmupIterations := Trunc(Iterations * (GConfig.WarmupMs / GConfig.TargetMs));
    if WarmupIterations < 1 then WarmupIterations := 1;
    Proc(WarmupIterations);
  end;
  SetLength(Samples, GConfig.Samples);
  for I := 0 to High(Samples) do Samples[I] := MeasureNs(Proc, Iterations) / Iterations;
  SetLength(Sorted, Length(Samples));
  for I := 0 to High(Samples) do Sorted[I] := Samples[I];
  SortDoubles(Sorted);
  Sum := 0;
  for I := 0 to High(Samples) do Sum := Sum + Samples[I];
  Result.SectionName := SectionName;
  Result.Name := Name;
  Result.UnitName := UnitName;
  Result.Iterations := Iterations;
  Result.UnitsPerOp := UnitsPerOp;
  Result.Samples := Length(Samples);
  Result.MedianNs := MedianOf(Sorted);
  Result.MinNs := Sorted[0];
  Result.MaxNs := Sorted[High(Sorted)];
  Result.MeanNs := Sum / Length(Samples);
  Variance := 0;
  for I := 0 to High(Samples) do
  begin
    D := Samples[I] - Result.MeanNs;
    Variance := Variance + D * D;
  end;
  if Length(Samples) > 1 then Variance := Variance / (Length(Samples) - 1);
  if Result.MeanNs > 0 then Result.RsdPct := Sqrt(Variance) / Result.MeanNs * 100 else Result.RsdPct := 0;
  UnitsPerSecond := UnitsPerOp * 1000000000.0 / Result.MedianNs;
  case Kind of
    tkBytes:
      begin
        Result.Throughput := UnitsPerSecond / 1048576.0;
        Result.ThroughputUnit := 'MiB/s';
      end;
    tkOperations:
      begin
        Result.Throughput := UnitsPerSecond / 1000000.0;
        Result.ThroughputUnit := 'Mops/s';
      end;
    tkValues:
      begin
        Result.Throughput := UnitsPerSecond / 1000000.0;
        Result.ThroughputUnit := 'Mval/s';
      end;
  end;
  N := Length(GResults);
  SetLength(GResults, N + 1);
  GResults[N] := Result;
  Writeln(Format('%-42s %10d %14s %10.2f %-5s %8.2f', [Name, Iterations, FormatDuration(Result.MedianNs), Result.Throughput, Result.ThroughputUnit, Result.RsdPct]));
end;

procedure WriteCsv(const FileName: string);
var
  Lines: TStringList;
  I: Integer;
  R: TBenchResult;
  FS: TFormatSettings;
  function F(Value: Double): string;
  begin
    Result := FloatToStrF(Value, ffFixed, 18, 6, FS);
  end;
begin
  if FileName = '' then Exit;
  FS := TFormatSettings.Invariant;
  Lines := TStringList.Create;
  try
    Lines.Add('section,name,unit,iterations,units_per_op,samples,median_ns,min_ns,max_ns,mean_ns,rsd_percent,throughput,throughput_unit,cpu,compiler_version,qpc_frequency,target_ms,warmup_ms,mode');
    for I := 0 to High(GResults) do
    begin
      R := GResults[I];
      Lines.Add('"' + StringReplace(R.SectionName, '"', '""', [rfReplaceAll]) + '","' + StringReplace(R.Name, '"', '""', [rfReplaceAll]) + '","' + R.UnitName + '",' + IntToStr(R.Iterations) + ',' + IntToStr(R.UnitsPerOp) + ',' + IntToStr(R.Samples) + ',' + F(R.MedianNs) + ',' + F(R.MinNs) + ',' + F(R.MaxNs) + ',' + F(R.MeanNs) + ',' + F(R.RsdPct) + ',' + F(R.Throughput) + ',"' + R.ThroughputUnit + '","' + StringReplace(GetEnvironmentVariable('PROCESSOR_IDENTIFIER'), '"', '""', [rfReplaceAll]) + '",' + F(CompilerVersion) + ',' + IntToStr(GFrequency) + ',' + IntToStr(GConfig.TargetMs) + ',' + IntToStr(GConfig.WarmupMs) + ',"' + GConfig.ModeName + '"');
    end;
    Lines.SaveToFile(FileName, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
end;

end.

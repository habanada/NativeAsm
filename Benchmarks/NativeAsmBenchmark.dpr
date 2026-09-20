program NativeAsmBenchmark;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  Winapi.Windows,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.JitAlloc;

type
  TBenchProc = reference to procedure(Iterations: Int64);

  TBenchConfig = record
    TargetMs: Integer;
    WarmupMs: Integer;
    Samples: Integer;
    CsvPath: string;
  end;

  TBenchResult = record
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
    NsPerUnit: Double;
    MillionUnitsPerSec: Double;
  end;

var
  GConfig: TBenchConfig;
  GFrequency: Int64;
  GSink: UInt64;
  GCpuId: string;
  GLogicalProcessors: Cardinal;
  GResults: array of TBenchResult;

function NowTicks: Int64; inline;
begin
  QueryPerformanceCounter(Result);
end;

function TicksToNs(Ticks: Int64): Double; inline;
begin
  Result := Ticks * (1000000000.0 / GFrequency);
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
  for Attempt := 1 to 12 do
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
  if Odd(N) then Result := Sorted[N div 2]
  else Result := (Sorted[N div 2 - 1] + Sorted[N div 2]) * 0.5;
end;

procedure AddResult(const R: TBenchResult);
var
  N: Integer;
begin
  N := Length(GResults);
  SetLength(GResults, N + 1);
  GResults[N] := R;
end;

procedure RunBenchmark(const Name, UnitName: string; UnitsPerOp: Int64; const Proc: TBenchProc);
var
  Samples, Sorted: TArray<Double>;
  Iterations, WarmupIterations: Int64;
  I: Integer;
  Sum, Variance, D: Double;
  R: TBenchResult;
begin
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

  R.Name := Name;
  R.UnitName := UnitName;
  R.Iterations := Iterations;
  R.UnitsPerOp := UnitsPerOp;
  R.Samples := Length(Samples);
  R.MedianNs := MedianOf(Sorted);
  R.MinNs := Sorted[0];
  R.MaxNs := Sorted[High(Sorted)];
  R.MeanNs := Sum / Length(Samples);
  Variance := 0;
  for I := 0 to High(Samples) do
  begin
    D := Samples[I] - R.MeanNs;
    Variance := Variance + D * D;
  end;
  if Length(Samples) > 1 then Variance := Variance / (Length(Samples) - 1);
  if R.MeanNs > 0 then R.RsdPct := Sqrt(Variance) / R.MeanNs * 100 else R.RsdPct := 0;
  R.NsPerUnit := R.MedianNs / UnitsPerOp;
  if R.NsPerUnit > 0 then R.MillionUnitsPerSec := 1000.0 / R.NsPerUnit else R.MillionUnitsPerSec := 0;
  AddResult(R);

  Writeln(Format('%-30s %-14s %10d %12.2f %12.3f %12.2f %8.2f', [Name, UnitName, Iterations, R.MedianNs, R.NsPerUnit, R.MillionUnitsPerSec, R.RsdPct]));
end;

procedure EmitGprMix(B: TAsmBuilder);
begin
  B.Mov(RAX, RCX).Mov(R8, R9).Add(RAX, RDX).Sub(R8, 7).Xor_(R10, R11).And_(RAX, R8).Or_(R9, R10).Cmp(RAX, RBX).Test(R8, R8).Imul(R10, R11).Shl_(RAX, 3).Shr_(R8, 5).Sar(RDX, 7).Bswap(R10).Inc_(R11).Dec_(R12);
end;

procedure EmitMemoryMix(B: TAsmBuilder);
begin
  B.Mov(RAX, QWordPtr(ridRCX)).Mov(QWordPtr(ridRCX, 8), RAX).Mov(R8, QWordPtr(ridRDX, 127)).Mov(QWordPtr(ridRDX, -128), R8).Lea(R9, TMemory.CreateSib(ridRCX, ridRDX, s4, 16)).Movzx(R10, BytePtr(ridRCX, 31)).Movzx(R11, WordPtr(ridRDX, 64)).Movsx(R12, BytePtr(ridRCX, -32)).Movsx(R13, WordPtr(ridRDX, 128)).Mov(EAX, DWordPtr(ridRCX, 4)).Mov(DWordPtr(ridRCX, 12), EAX).Lea(R14, TMemory.CreateSib(ridR12, ridR13, s8, 128));
end;

function MakeSmallCode: TBytes;
var
  B: TAsmBuilder;
begin
  B := TAsmBuilder.New;
  try
    B.Mov(RAX, RCX).Add(RAX, RDX).Xor_(RAX, R8).Ret;
    Result := B.Build;
  finally
    B.Free;
  end;
end;

function MakeLoopCode: TBytes;
var
  B: TAsmBuilder;
  L: TLabel;
begin
  B := TAsmBuilder.New;
  try
    L := B.NewLabel;
    B.Xor_(RAX, RAX).Bind(L).Add(RAX, 1).Dec_(RCX).J(cond_JNE, L).Ret;
    Result := B.Build;
  finally
    B.Free;
  end;
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
    Lines.Add('name,unit,iterations,units_per_op,samples,median_ns_per_op,min_ns_per_op,max_ns_per_op,mean_ns_per_op,rsd_percent,median_ns_per_unit,million_units_per_sec,cpu,logical_processors,compiler_version,qpc_frequency,target_ms,warmup_ms');
    for I := 0 to High(GResults) do
    begin
      R := GResults[I];
      Lines.Add('"' + StringReplace(R.Name, '"', '""', [rfReplaceAll]) + '","' + R.UnitName + '",' + IntToStr(R.Iterations) + ',' + IntToStr(R.UnitsPerOp) + ',' + IntToStr(R.Samples) + ',' + F(R.MedianNs) + ',' + F(R.MinNs) + ',' + F(R.MaxNs) + ',' + F(R.MeanNs) + ',' + F(R.RsdPct) + ',' + F(R.NsPerUnit) + ',' + F(R.MillionUnitsPerSec) + ',"' + StringReplace(GCpuId, '"', '""', [rfReplaceAll]) + '",' + IntToStr(GLogicalProcessors) + ',' + F(CompilerVersion) + ',' + IntToStr(GFrequency) + ',' + IntToStr(GConfig.TargetMs) + ',' + IntToStr(GConfig.WarmupMs));
    end;
    Lines.SaveToFile(FileName, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
end;

procedure ParseArgs;
var
  I, V: Integer;
  S, Value: string;
begin
  GConfig.TargetMs := 200;
  GConfig.WarmupMs := 300;
  GConfig.Samples := 9;
  GConfig.CsvPath := '';
  for I := 1 to ParamCount do
  begin
    S := ParamStr(I);
    if SameText(S, '--quick') then
    begin
      GConfig.TargetMs := 75;
      GConfig.WarmupMs := 100;
      GConfig.Samples := 5;
    end
    else if SameText(S, '--full') then
    begin
      GConfig.TargetMs := 500;
      GConfig.WarmupMs := 1000;
      GConfig.Samples := 15;
    end
    else if Pos('--target-ms=', LowerCase(S)) = 1 then
    begin
      Value := Copy(S, Length('--target-ms=') + 1, MaxInt);
      if not TryStrToInt(Value, V) or (V < 10) then raise EArgumentException.Create('invalid --target-ms');
      GConfig.TargetMs := V;
    end
    else if Pos('--warmup-ms=', LowerCase(S)) = 1 then
    begin
      Value := Copy(S, Length('--warmup-ms=') + 1, MaxInt);
      if not TryStrToInt(Value, V) or (V < 0) then raise EArgumentException.Create('invalid --warmup-ms');
      GConfig.WarmupMs := V;
    end
    else if Pos('--samples=', LowerCase(S)) = 1 then
    begin
      Value := Copy(S, Length('--samples=') + 1, MaxInt);
      if not TryStrToInt(Value, V) or (V < 3) then raise EArgumentException.Create('invalid --samples');
      GConfig.Samples := V;
    end
    else if Pos('--csv=', LowerCase(S)) = 1 then GConfig.CsvPath := Copy(S, Length('--csv=') + 1, MaxInt)
    else if SameText(S, '--help') or SameText(S, '-h') then
    begin
      Writeln('NativeAsmBenchmark [--quick|--full] [--target-ms=N] [--warmup-ms=N] [--samples=N] [--csv=file]');
      Halt(0);
    end
    else raise EArgumentException.CreateFmt('unknown argument: %s', [S]);
  end;
end;

procedure PrintHeader;
var
  SI: TSystemInfo;
begin
  GetSystemInfo(SI);
  GCpuId := GetEnvironmentVariable('PROCESSOR_IDENTIFIER');
  GLogicalProcessors := SI.dwNumberOfProcessors;
  Writeln('NativeAsm Win64 Benchmark');
  Writeln('Mode: Release / optimized');
  Writeln('CPU: ', GCpuId);
  Writeln(Format('CPU logical processors: %d', [GLogicalProcessors]));
  Writeln(Format('Process: %d-bit  CompilerVersion: %.1f', [SizeOf(Pointer) * 8, CompilerVersion]));
  Writeln(Format('QPC frequency: %d Hz', [GFrequency]));
  Writeln(Format('Target/sample: %d ms  Warmup: %d ms  Samples: %d', [GConfig.TargetMs, GConfig.WarmupMs, GConfig.Samples]));
  Writeln;
  Writeln(Format('%-30s %-14s %10s %12s %12s %12s %8s', ['Benchmark', 'Unit', 'Iterations', 'ns/op', 'ns/unit', 'Munit/s', 'RSD%']));
  Writeln(StringOfChar('-', 116));
end;

procedure RunAll;
const
  LoopWork = 1024;
  BatchFunctions = 256;
var
  B: TAsmBuilder;
  BuildBlock: TAsmBuilder;
  SmallCode, LoopCode, Built: TBytes;
  SmallExe, LoopExe: TExecutableCode;
  DirectFn: TAsmFunc3;
  LoopFn: TAsmFunc1;
  Expected: UInt64;
begin
  B := TAsmBuilder.New;
  BuildBlock := TAsmBuilder.New;
  SmallCode := MakeSmallCode;
  LoopCode := MakeLoopCode;
  SmallExe := TExecutableCode.Create(SmallCode);
  LoopExe := TExecutableCode.Create(LoopCode);
  try
    DirectFn := TAsmFunc3(SmallExe.EntryPoint);
    LoopFn := TAsmFunc1(LoopExe.EntryPoint);
    Expected := (UInt64(7) + UInt64(11)) xor UInt64(13);
    if SmallExe.Run(7, 11, 13) <> Expected then raise Exception.Create('small JIT validation failed');
    if LoopExe.Run(LoopWork) <> LoopWork then raise Exception.Create('loop JIT validation failed');

    RunBenchmark('Encode.GprMix16', 'instruction', 16,
      procedure(Iterations: Int64)
      var I: Int64;
      begin
        for I := 1 to Iterations do begin B.Reset; EmitGprMix(B); end;
        GSink := GSink xor UInt64(B.CodeSize);
      end);

    RunBenchmark('Encode.MemoryMix12', 'instruction', 12,
      procedure(Iterations: Int64)
      var I: Int64;
      begin
        for I := 1 to Iterations do begin B.Reset; EmitMemoryMix(B); end;
        GSink := GSink xor UInt64(B.CodeSize);
      end);

    RunBenchmark('Build.LabelFixups7', 'instruction', 7,
      procedure(Iterations: Int64)
      var I: Int64; L0, L1: TLabel; Code: TBytes;
      begin
        for I := 1 to Iterations do
        begin
          B.Reset;
          L0 := B.NewLabel;
          L1 := B.NewLabel;
          B.Bind(L0).Cmp(RAX, 0).J(cond_JE, L1).Add(RAX, 1).Sub(RDX, 1).J(cond_JNE, L0).Xor_(RAX, RDX).Bind(L1).Ret;
          Code := B.Build;
          GSink := GSink xor UInt64(Length(Code));
        end;
      end);

    BuildBlock.Reset;
    while BuildBlock.CodeSize < 4096 do EmitGprMix(BuildBlock);
    RunBenchmark('Build.Copy4K', 'byte', BuildBlock.CodeSize,
      procedure(Iterations: Int64)
      var I: Int64; Code: TBytes;
      begin
        for I := 1 to Iterations do begin Code := BuildBlock.Build; GSink := GSink xor UInt64(Length(Code)); end;
      end);

    RunBenchmark('Build.LargeMixed256', 'instruction', 256,
      procedure(Iterations: Int64)
      var I: Int64; J: Integer; Code: TBytes;
      begin
        for I := 1 to Iterations do
        begin
          B.Reset;
          for J := 1 to 16 do EmitGprMix(B);
          Code := B.Build;
          GSink := GSink xor UInt64(Length(Code));
        end;
      end);

    RunBenchmark('Jit.OwnAllocation', 'function', 1,
      procedure(Iterations: Int64)
      var I: Int64; Exe: TExecutableCode;
      begin
        for I := 1 to Iterations do
        begin
          Exe := TExecutableCode.Create(SmallCode);
          try GSink := GSink xor UInt64(Exe.Size) finally Exe.Free end;
        end;
      end);

    RunBenchmark('Jit.AllocatorBatch256', 'function', BatchFunctions,
      procedure(Iterations: Int64)
      var I: Int64; J: Integer; Pool: TJitAllocator; P: Pointer;
      begin
        for I := 1 to Iterations do
        begin
          Pool := TJitAllocator.Create;
          try
            for J := 1 to BatchFunctions do
            begin
              P := Pool.Alloc(Length(SmallCode));
              Move(SmallCode[0], P^, Length(SmallCode));
            end;
            Pool.CommitAll;
            GSink := GSink xor UInt64(Pool.TotalUsed);
          finally
            Pool.Free;
          end;
        end;
      end);

    RunBenchmark('Execute.DirectCall', 'call', 1,
      procedure(Iterations: Int64)
      var I: Int64; R: UInt64;
      begin
        R := 0;
        for I := 1 to Iterations do R := R xor DirectFn(UInt64(I), 11, 13);
        GSink := GSink xor R;
      end);

    RunBenchmark('Execute.RunAPI', 'call', 1,
      procedure(Iterations: Int64)
      var I: Int64; R: UInt64;
      begin
        R := 0;
        for I := 1 to Iterations do R := R xor SmallExe.Run(UInt64(I), 11, 13);
        GSink := GSink xor R;
      end);

    RunBenchmark('Execute.GeneratedLoop1024', 'loop-iteration', LoopWork,
      procedure(Iterations: Int64)
      var I: Int64; R: UInt64;
      begin
        R := 0;
        for I := 1 to Iterations do R := R xor LoopFn(LoopWork);
        GSink := GSink xor R;
      end);

    RunBenchmark('EndToEnd.BuildJitRun', 'function', 1,
      procedure(Iterations: Int64)
      var I: Int64; Builder: TAsmBuilder; Exe: TExecutableCode; R: UInt64;
      begin
        R := 0;
        for I := 1 to Iterations do
        begin
          Builder := TAsmBuilder.New;
          try
            Builder.Mov(RAX, RCX).Add(RAX, RDX).Xor_(RAX, R8).Ret;
            Exe := TExecutableCode.FromBuilder(Builder);
            try R := R xor Exe.Run(UInt64(I), 11, 13) finally Exe.Free end;
          finally
            Builder.Free;
          end;
        end;
        GSink := GSink xor R;
      end);

    Built := BuildBlock.Build;
    GSink := GSink xor UInt64(Length(Built));
  finally
    LoopExe.Free;
    SmallExe.Free;
    BuildBlock.Free;
    B.Free;
  end;
end;

begin
  try
{$IFDEF DEBUG}
    Writeln('NativeAsmBenchmark must be built with the Release configuration.');
    Halt(2);
{$ENDIF}
    ParseArgs;
    if not QueryPerformanceFrequency(GFrequency) or (GFrequency <= 0) then raise Exception.Create('QueryPerformanceFrequency failed');
    PrintHeader;
    RunAll;
    Writeln(StringOfChar('-', 116));
    Writeln(Format('Sink: $%s', [IntToHex(Int64(GSink), 16)]));
    WriteCsv(GConfig.CsvPath);
    if GConfig.CsvPath <> '' then Writeln('CSV: ', ExpandFileName(GConfig.CsvPath));
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.

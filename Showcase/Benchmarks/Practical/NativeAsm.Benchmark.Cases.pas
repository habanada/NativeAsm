{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Benchmark.Cases;

interface

procedure RunAllBenchmarks;

implementation

uses
  System.SysUtils,
  NativeAsm.CpuFeatures,
  NativeAsm.Algorithms.Crc32,
  NativeAsm.Algorithms.Crc32C,
  NativeAsm.Algorithms.Hash64,
  NativeAsm.Algorithms.Base64,
  NativeAsm.Algorithms.Hex,
  NativeAsm.Algorithms.BloomFilter,
  NativeAsm.Crypto.ChaCha20,
  NativeAsm.Crypto.Poly1305,
  NativeAsm.Crypto.ChaCha20Poly1305,
  NativeAsm.Crypto.Blake3,
  NativeAsm.Random.Xoshiro256pp,
  NativeAsm.BigInt.Types,
  NativeAsm.BigInt.Core,
  NativeAsm.BigInt.Jit,
  NativeAsm.BigInt.Montgomery,
  NativeAsm.BigInt.Fields,
  NativeAsm.Benchmark.Common;

type
  TCreateProc = reference to function: TObject;

function MakeData(Count: Integer; Seed: Cardinal = 17): TBytes;
var
  I: Integer;
  X: Cardinal;
begin
  SetLength(Result, Count);
  X := Seed;
  for I := 0 to High(Result) do
  begin
    X := X * 1664525 + 1013904223;
    Result[I] := Byte(X shr 24);
  end;
end;

function MeasureCreateMs(const CreateProc: TCreateProc): Double;
var
  T0, T1: Int64;
  O: TObject;
begin
  T0 := NowTicks;
  O := CreateProc;
  T1 := NowTicks;
  O.Free;
  Result := TicksToNs(T1 - T0) / 1000000.0;
end;

function OptionalSetup(Available: Boolean; const CreateProc: TCreateProc): string;
begin
  if Available then Result := Format('%.3f ms', [MeasureCreateMs(CreateProc)]) else Result := 'n/a';
end;
function Crc32ModeText(Mode: TCrc32Mode): string;
begin
  case Mode of
    crc32mScalar: Result := 'scalar';
    crc32mPclmul: Result := 'pclmul';
  else
    Result := 'auto';
  end;
end;

function Crc32CModeText(Mode: TCrc32CMode): string;
begin
  case Mode of
    cmScalar: Result := 'scalar';
    cmSse42: Result := 'sse4.2';
  else
    Result := 'auto';
  end;
end;

function Blake3ModeText(Mode: TBlake3Mode): string;
begin
  case Mode of
    b3mScalar: Result := 'scalar';
    b3mSse2: Result := 'sse2';
    b3mSsse3: Result := 'ssse3';
  else
    Result := 'auto';
  end;
end;

function ChaChaModeText(Mode: TChaCha20Mode): string;
begin
  case Mode of
    ccmScalar: Result := 'scalar';
    ccmSse2: Result := 'sse2';
  else
    Result := 'auto';
  end;
end;

function Base64ModeText(Mode: TBase64Mode): string;
begin
  case Mode of
    b64mScalar: Result := 'scalar';
    b64mSsse3: Result := 'ssse3';
  else
    Result := 'auto';
  end;
end;

function HexModeText(Mode: THexMode): string;
begin
  case Mode of
    hmScalar: Result := 'scalar';
    hmSsse3: Result := 'ssse3';
  else
    Result := 'auto';
  end;
end;

procedure PrintSpeedup(const Name: string; BaseResult, FastResult: TBenchResult);
begin
  if FastResult.MedianNs > 0 then Writeln(Format('  speedup %-18s %.2fx', [Name, BaseResult.MedianNs / FastResult.MedianNs]));
end;

procedure RunCrc32;
const
  FullSizes: array[0..3] of Integer = (64, 4096, 1048576, 8388608);
  QuickSizes: array[0..1] of Integer = (4096, 1048576);
var
  Data: TBytes;
  Scalar, Pclmul, Auto: TCrc32Jit;
  RScalar, RFast, RAuto: TBenchResult;
  Size, K, Count: Integer;
  PclmulAvailable: Boolean;
begin
  PrintSection('CRC32 IEEE');
  PclmulAvailable := TCrc32Jit.IsPclmulAvailable;
  Writeln(Format('setup scalar=%.3f ms  pclmul=%s  auto=%.3f ms', [MeasureCreateMs(function: TObject begin Result := TCrc32Jit.Create(crc32mScalar) end), OptionalSetup(PclmulAvailable, function: TObject begin Result := TCrc32Jit.Create(crc32mPclmul) end), MeasureCreateMs(function: TObject begin Result := TCrc32Jit.Create(crc32mAuto) end)]));
  Data := MakeData(8388608, 11);
  Scalar := TCrc32Jit.Create(crc32mScalar);
  Pclmul := nil;
  if PclmulAvailable then Pclmul := TCrc32Jit.Create(crc32mPclmul);
  Auto := TCrc32Jit.Create(crc32mAuto);
  Writeln('active auto=', Crc32ModeText(Auto.Mode));
  try
    if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickSizes) else Count := Length(FullSizes);
    for K := 0 to Count - 1 do
    begin
      if SameText(GConfig.ModeName, 'quick') then Size := QuickSizes[K] else Size := FullSizes[K];
      RScalar := RunBenchmark('CRC32 IEEE', 'CRC32 scalar ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var I: Int64; V: Cardinal;
        begin
          V := 0;
          for I := 1 to Iterations do V := V xor Scalar.Compute(@Data[0], Size);
          Sink(V);
        end);
      if Pclmul <> nil then
      begin
        RFast := RunBenchmark('CRC32 IEEE', 'CRC32 PCLMUL ' + FormatBytes(Size), 'byte', Size, tkBytes,
          procedure(Iterations: Int64)
          var I: Int64; V: Cardinal;
          begin
            V := 0;
            for I := 1 to Iterations do V := V xor Pclmul.Compute(@Data[0], Size);
            Sink(V);
          end);
        PrintSpeedup('PCLMUL', RScalar, RFast);
      end;
      RAuto := RunBenchmark('CRC32 IEEE', 'CRC32 auto ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var I: Int64; V: Cardinal;
        begin
          V := 0;
          for I := 1 to Iterations do V := V xor Auto.Compute(@Data[0], Size);
          Sink(V);
        end);
      PrintSpeedup('auto', RScalar, RAuto);
    end;
    if not SameText(GConfig.ModeName, 'quick') then
      RunBenchmark('CRC32 IEEE', 'CRC32 auto unaligned +1 1.0 MiB', 'byte', 1048576, tkBytes,
        procedure(Iterations: Int64)
        var I: Int64; V: Cardinal;
        begin
          V := 0;
          for I := 1 to Iterations do V := V xor Auto.Compute(@Data[1], 1048576);
          Sink(V);
        end);
  finally
    Auto.Free;
    Pclmul.Free;
    Scalar.Free;
  end;
end;

procedure RunCrc32C;
const
  FullSizes: array[0..3] of Integer = (64, 4096, 1048576, 8388608);
  QuickSizes: array[0..1] of Integer = (4096, 1048576);
var
  Data: TBytes;
  Scalar, Sse42, Auto: TCrc32CJit;
  RScalar, RFast, RAuto: TBenchResult;
  Size, K, Count: Integer;
  Sse42Available: Boolean;
begin
  PrintSection('CRC32C Castagnoli');
  Sse42Available := TCrc32CJit.IsSse42Available;
  Writeln(Format('setup scalar=%.3f ms  sse4.2=%s  auto=%.3f ms', [MeasureCreateMs(function: TObject begin Result := TCrc32CJit.Create(cmScalar) end), OptionalSetup(Sse42Available, function: TObject begin Result := TCrc32CJit.Create(cmSse42) end), MeasureCreateMs(function: TObject begin Result := TCrc32CJit.Create(cmAuto) end)]));
  Data := MakeData(8388608, 23);
  Scalar := TCrc32CJit.Create(cmScalar);
  Sse42 := nil;
  if Sse42Available then Sse42 := TCrc32CJit.Create(cmSse42);
  Auto := TCrc32CJit.Create(cmAuto);
  Writeln('active auto=', Crc32CModeText(Auto.Mode));
  try
    if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickSizes) else Count := Length(FullSizes);
    for K := 0 to Count - 1 do
    begin
      if SameText(GConfig.ModeName, 'quick') then Size := QuickSizes[K] else Size := FullSizes[K];
      RScalar := RunBenchmark('CRC32C Castagnoli', 'CRC32C scalar ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var I: Int64; V: Cardinal;
        begin
          V := 0;
          for I := 1 to Iterations do V := V xor Scalar.Compute(@Data[0], Size);
          Sink(V);
        end);
      if Sse42 <> nil then
      begin
        RFast := RunBenchmark('CRC32C Castagnoli', 'CRC32C SSE4.2 ' + FormatBytes(Size), 'byte', Size, tkBytes,
          procedure(Iterations: Int64)
          var I: Int64; V: Cardinal;
          begin
            V := 0;
            for I := 1 to Iterations do V := V xor Sse42.Compute(@Data[0], Size);
            Sink(V);
          end);
        PrintSpeedup('SSE4.2', RScalar, RFast);
      end;
      RAuto := RunBenchmark('CRC32C Castagnoli', 'CRC32C auto ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var I: Int64; V: Cardinal;
        begin
          V := 0;
          for I := 1 to Iterations do V := V xor Auto.Compute(@Data[0], Size);
          Sink(V);
        end);
      PrintSpeedup('auto', RScalar, RAuto);
    end;
    if not SameText(GConfig.ModeName, 'quick') then
      RunBenchmark('CRC32C Castagnoli', 'CRC32C auto unaligned +1 1.0 MiB', 'byte', 1048576, tkBytes,
        procedure(Iterations: Int64)
        var I: Int64; V: Cardinal;
        begin
          V := 0;
          for I := 1 to Iterations do V := V xor Auto.Compute(@Data[1], 1048576);
          Sink(V);
        end);
  finally
    Auto.Free;
    Sse42.Free;
    Scalar.Free;
  end;
end;

procedure RunHash64;
const
  FullSizes: array[0..3] of Integer = (64, 4096, 1048576, 8388608);
  QuickSizes: array[0..1] of Integer = (4096, 1048576);
var
  Data: TBytes;
  Jit: THash64Jit;
  Size, K, Count: Integer;
begin
  PrintSection('FNV-1a 64');
  Writeln(Format('setup=%.3f ms', [MeasureCreateMs(function: TObject begin Result := THash64Jit.Create end)]));
  Data := MakeData(8388608, 37);
  Jit := THash64Jit.Create;
  try
    if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickSizes) else Count := Length(FullSizes);
    for K := 0 to Count - 1 do
    begin
      if SameText(GConfig.ModeName, 'quick') then Size := QuickSizes[K] else Size := FullSizes[K];
      RunBenchmark('FNV-1a 64', 'FNV-1a 64 ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var I: Int64; V: UInt64;
        begin
          V := 0;
          for I := 1 to Iterations do V := V xor Jit.Hash(@Data[0], Size);
          Sink(V);
        end);
    end;
    RunBenchmark('FNV-1a 64', 'Hash64 mix dependent chain', 'value', 1, tkValues,
      procedure(Iterations: Int64)
      var I: Int64; V: UInt64;
      begin
        V := UInt64($9E3779B97F4A7C15);
        for I := 1 to Iterations do V := Jit.Mix(V + UInt64(I));
        Sink(V);
      end);
  finally
    Jit.Free;
  end;
end;

procedure RunBlake3;
const
  FullSizes: array[0..7] of Integer = (64, 1024, 4096, 4097, 8192, 8193, 1048576, 8388608);
  QuickSizes: array[0..1] of Integer = (4096, 1048576);
var
  Data: TBytes;
  Scalar, Sse2, Ssse3, Auto: TBlake3Jit;
  RScalar, RSse2, RSsse3, RAuto: TBenchResult;
  Size, K, Count: Integer;
begin
  PrintSection('BLAKE3');
  Writeln(Format('setup scalar=%.3f ms  sse2=%s  ssse3=%s  auto=%.3f ms', [MeasureCreateMs(function: TObject begin Result := TBlake3Jit.Create(b3mScalar) end), OptionalSetup(TBlake3Jit.IsSse2Available, function: TObject begin Result := TBlake3Jit.Create(b3mSse2) end), OptionalSetup(TBlake3Jit.IsSsse3Available, function: TObject begin Result := TBlake3Jit.Create(b3mSsse3) end), MeasureCreateMs(function: TObject begin Result := TBlake3Jit.Create(b3mAuto) end)]));
  Data := MakeData(8388608, 41);
  Scalar := TBlake3Jit.Create(b3mScalar);
  Sse2 := nil;
  Ssse3 := nil;
  if TBlake3Jit.IsSse2Available then Sse2 := TBlake3Jit.Create(b3mSse2);
  if TBlake3Jit.IsSsse3Available then Ssse3 := TBlake3Jit.Create(b3mSsse3);
  Auto := TBlake3Jit.Create(b3mAuto);
  Writeln('active auto=', Blake3ModeText(Auto.Mode));
  try
    if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickSizes) else Count := Length(FullSizes);
    for K := 0 to Count - 1 do
    begin
      if SameText(GConfig.ModeName, 'quick') then Size := QuickSizes[K] else Size := FullSizes[K];
      RScalar := RunBenchmark('BLAKE3', 'BLAKE3 scalar ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var I: Int64; D: TBlake3Digest; V: UInt64;
        begin
          V := 0;
          for I := 1 to Iterations do begin D := Scalar.Compute(@Data[0], Size); V := V xor UInt64(D[0]) xor (UInt64(D[31]) shl 8); end;
          Sink(V);
        end);
      if Sse2 <> nil then
      begin
        RSse2 := RunBenchmark('BLAKE3', 'BLAKE3 SSE2 ' + FormatBytes(Size), 'byte', Size, tkBytes,
          procedure(Iterations: Int64)
          var I: Int64; D: TBlake3Digest; V: UInt64;
          begin
            V := 0;
            for I := 1 to Iterations do begin D := Sse2.Compute(@Data[0], Size); V := V xor UInt64(D[0]) xor (UInt64(D[31]) shl 8); end;
            Sink(V);
          end);
        PrintSpeedup('SSE2', RScalar, RSse2);
      end;
      if Ssse3 <> nil then
      begin
        RSsse3 := RunBenchmark('BLAKE3', 'BLAKE3 SSSE3 ' + FormatBytes(Size), 'byte', Size, tkBytes,
          procedure(Iterations: Int64)
          var I: Int64; D: TBlake3Digest; V: UInt64;
          begin
            V := 0;
            for I := 1 to Iterations do begin D := Ssse3.Compute(@Data[0], Size); V := V xor UInt64(D[0]) xor (UInt64(D[31]) shl 8); end;
            Sink(V);
          end);
        PrintSpeedup('SSSE3', RScalar, RSsse3);
      end;
      RAuto := RunBenchmark('BLAKE3', 'BLAKE3 auto ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var I: Int64; D: TBlake3Digest; V: UInt64;
        begin
          V := 0;
          for I := 1 to Iterations do begin D := Auto.Compute(@Data[0], Size); V := V xor UInt64(D[0]) xor (UInt64(D[31]) shl 8); end;
          Sink(V);
        end);
      PrintSpeedup('auto', RScalar, RAuto);
    end;
    if not SameText(GConfig.ModeName, 'quick') then
      RunBenchmark('BLAKE3', 'BLAKE3 auto unaligned +1 1.0 MiB', 'byte', 1048576, tkBytes,
        procedure(Iterations: Int64)
        var I: Int64; D: TBlake3Digest; V: UInt64;
        begin
          V := 0;
          for I := 1 to Iterations do begin D := Auto.Compute(@Data[1], 1048576); V := V xor UInt64(D[0]) xor (UInt64(D[31]) shl 8); end;
          Sink(V);
        end);
  finally
    Auto.Free;
    Ssse3.Free;
    Sse2.Free;
    Scalar.Free;
  end;
end;

procedure RunChaCha20;
const
  FullSizes: array[0..3] of Integer = (64, 4096, 1048576, 8388608);
  QuickSizes: array[0..1] of Integer = (4096, 1048576);
var
  Data, Output: TBytes;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Scalar, Sse2, Auto: TChaCha20Jit;
  RScalar, RFast, RAuto: TBenchResult;
  Size, K, Count, I: Integer;
begin
  PrintSection('ChaCha20');
  Writeln(Format('setup scalar=%.3f ms  sse2=%s  auto=%.3f ms', [MeasureCreateMs(function: TObject begin Result := TChaCha20Jit.Create(ccmScalar) end), OptionalSetup(TCpuFeatures.Supports(cfSSE2), function: TObject begin Result := TChaCha20Jit.Create(ccmSse2) end), MeasureCreateMs(function: TObject begin Result := TChaCha20Jit.Create(ccmAuto) end)]));
  Data := MakeData(8388608, 53);
  SetLength(Output, Length(Data));
  for I := 0 to High(Key) do Key[I] := Byte(I * 7 + 3);
  for I := 0 to High(Nonce) do Nonce[I] := Byte(I * 11 + 5);
  Scalar := TChaCha20Jit.Create(ccmScalar);
  Sse2 := nil;
  if TCpuFeatures.Supports(cfSSE2) then Sse2 := TChaCha20Jit.Create(ccmSse2);
  Auto := TChaCha20Jit.Create(ccmAuto);
  Writeln('active auto=', ChaChaModeText(Auto.Mode));
  try
    if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickSizes) else Count := Length(FullSizes);
    for K := 0 to Count - 1 do
    begin
      if SameText(GConfig.ModeName, 'quick') then Size := QuickSizes[K] else Size := FullSizes[K];
      RScalar := RunBenchmark('ChaCha20', 'ChaCha20 scalar ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var N: Int64;
        begin
          for N := 1 to Iterations do Scalar.XorKeyStream(@Data[0], @Output[0], Size, Key, Nonce, 1);
          Sink(UInt64(Output[0]) xor (UInt64(Output[Size - 1]) shl 8));
        end);
      if Sse2 <> nil then
      begin
        RFast := RunBenchmark('ChaCha20', 'ChaCha20 SSE2 ' + FormatBytes(Size), 'byte', Size, tkBytes,
          procedure(Iterations: Int64)
          var N: Int64;
          begin
            for N := 1 to Iterations do Sse2.XorKeyStream(@Data[0], @Output[0], Size, Key, Nonce, 1);
            Sink(UInt64(Output[0]) xor (UInt64(Output[Size - 1]) shl 8));
          end);
        PrintSpeedup('SSE2', RScalar, RFast);
      end;
      RAuto := RunBenchmark('ChaCha20', 'ChaCha20 auto ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var N: Int64;
        begin
          for N := 1 to Iterations do Auto.XorKeyStream(@Data[0], @Output[0], Size, Key, Nonce, 1);
          Sink(UInt64(Output[0]) xor (UInt64(Output[Size - 1]) shl 8));
        end);
      PrintSpeedup('auto', RScalar, RAuto);
    end;
    if not SameText(GConfig.ModeName, 'quick') then
      RunBenchmark('ChaCha20', 'ChaCha20 auto unaligned +1 1.0 MiB', 'byte', 1048576, tkBytes,
        procedure(Iterations: Int64)
        var N: Int64;
        begin
          for N := 1 to Iterations do Auto.XorKeyStream(@Data[1], @Output[1], 1048576, Key, Nonce, 1);
          Sink(UInt64(Output[1]) xor (UInt64(Output[1048576]) shl 8));
        end);
  finally
    Auto.Free;
    Sse2.Free;
    Scalar.Free;
  end;
end;

procedure RunPoly1305;
const
  FullSizes: array[0..3] of Integer = (64, 4096, 1048576, 8388608);
  QuickSizes: array[0..1] of Integer = (4096, 1048576);
var
  Data: TBytes;
  Key: TPoly1305Key;
  Jit: TPoly1305Jit;
  Size, K, Count, I: Integer;
begin
  PrintSection('Poly1305');
  Writeln(Format('setup=%.3f ms', [MeasureCreateMs(function: TObject begin Result := TPoly1305Jit.Create end)]));
  Data := MakeData(8388608, 67);
  for I := 0 to High(Key) do Key[I] := Byte(I * 13 + 1);
  Jit := TPoly1305Jit.Create;
  try
    if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickSizes) else Count := Length(FullSizes);
    for K := 0 to Count - 1 do
    begin
      if SameText(GConfig.ModeName, 'quick') then Size := QuickSizes[K] else Size := FullSizes[K];
      RunBenchmark('Poly1305', 'Poly1305 ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var N: Int64; Tag: TPoly1305Tag; V: UInt64;
        begin
          V := 0;
          for N := 1 to Iterations do begin Tag := Jit.Compute(@Data[0], Size, Key); V := V xor UInt64(Tag[0]) xor (UInt64(Tag[15]) shl 8); end;
          Sink(V);
        end);
    end;
  finally
    Jit.Free;
  end;
end;

procedure RunAead;
const
  FullSizes: array[0..2] of Integer = (4096, 1048576, 8388608);
  QuickSizes: array[0..0] of Integer = (1048576);
var
  Plain, Cipher, Decoded, AAD: TBytes;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Tag: TPoly1305Tag;
  Aead: TChaCha20Poly1305Jit;
  Size, K, Count, I: Integer;
begin
  PrintSection('ChaCha20-Poly1305 AEAD');
  Writeln(Format('setup=%.3f ms', [MeasureCreateMs(function: TObject begin Result := TChaCha20Poly1305Jit.Create end)]));
  Plain := MakeData(8388608, 79);
  SetLength(Cipher, Length(Plain));
  SetLength(Decoded, Length(Plain));
  AAD := MakeData(32, 83);
  for I := 0 to High(Key) do Key[I] := Byte(I * 5 + 7);
  for I := 0 to High(Nonce) do Nonce[I] := Byte(I * 9 + 11);
  Aead := TChaCha20Poly1305Jit.Create;
  try
    if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickSizes) else Count := Length(FullSizes);
    for K := 0 to Count - 1 do
    begin
      if SameText(GConfig.ModeName, 'quick') then Size := QuickSizes[K] else Size := FullSizes[K];
      RunBenchmark('ChaCha20-Poly1305 AEAD', 'AEAD encrypt ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var N: Int64;
        begin
          for N := 1 to Iterations do Aead.Encrypt(@Plain[0], Size, @AAD[0], Length(AAD), @Cipher[0], Key, Nonce, Tag);
          Sink(UInt64(Tag[0]) xor (UInt64(Cipher[Size - 1]) shl 8));
        end);
      Aead.Encrypt(@Plain[0], Size, @AAD[0], Length(AAD), @Cipher[0], Key, Nonce, Tag);
      RunBenchmark('ChaCha20-Poly1305 AEAD', 'AEAD decrypt ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var N: Int64; Ok: Boolean;
        begin
          Ok := False;
          for N := 1 to Iterations do Ok := Aead.Decrypt(@Cipher[0], Size, @AAD[0], Length(AAD), @Decoded[0], Key, Nonce, Tag);
          if not Ok then raise Exception.Create('AEAD benchmark authentication failed');
          Sink(UInt64(Decoded[0]) xor (UInt64(Decoded[Size - 1]) shl 8));
        end);
    end;
  finally
    Aead.Free;
  end;
end;

procedure RunBase64;
const
  FullSizes: array[0..3] of Integer = (64, 4096, 1048576, 8388608);
  QuickSizes: array[0..1] of Integer = (4096, 1048576);
var
  Data, Encoded, Decoded: TBytes;
  Scalar, Ssse3, Auto: TBase64Jit;
  RScalar, RFast, RAuto: TBenchResult;
  Size, EncSize, K, Count: Integer;
  InvalidIndex: NativeInt;
  DecLen: NativeUInt;

  function EncodedLength(N: Integer): Integer;
  begin
    Result := ((N + 2) div 3) * 4;
  end;

  procedure PrepareEncoded(Jit: TBase64Jit; N: Integer);
  begin
    EncSize := EncodedLength(N);
    SetLength(Encoded, EncSize);
    SetLength(Decoded, N + 2);
    Jit.Encode(@Data[0], N, @Encoded[0]);
  end;

  procedure BenchMode(const Prefix: string; Jit: TBase64Jit; N: Integer; out RE, RD: TBenchResult);
  begin
    PrepareEncoded(Jit, N);
    RE := RunBenchmark('Base64', Prefix + ' encode ' + FormatBytes(N), 'byte', N, tkBytes,
      procedure(Iterations: Int64)
      var I: Int64;
      begin
        for I := 1 to Iterations do Jit.Encode(@Data[0], N, @Encoded[0]);
        Sink(UInt64(Encoded[0]) xor (UInt64(Encoded[EncSize - 1]) shl 8));
      end);
    RD := RunBenchmark('Base64', Prefix + ' decode ' + FormatBytes(N), 'byte', N, tkBytes,
      procedure(Iterations: Int64)
      var I: Int64; Ok: Boolean;
      begin
        Ok := False;
        for I := 1 to Iterations do Ok := Jit.TryDecode(@Encoded[0], EncSize, @Decoded[0], DecLen, InvalidIndex);
        if not Ok then raise Exception.Create('Base64 benchmark decode failed');
        Sink(UInt64(Decoded[0]) xor (UInt64(Decoded[N - 1]) shl 8) xor UInt64(DecLen));
      end);
  end;

var
  E0, D0, E1, D1, EA, DA: TBenchResult;
begin
  PrintSection('Base64');
  Writeln(Format('setup scalar=%.3f ms  ssse3=%s  auto=%.3f ms', [MeasureCreateMs(function: TObject begin Result := TBase64Jit.Create(b64mScalar) end), OptionalSetup(TCpuFeatures.Supports(cfSSSE3), function: TObject begin Result := TBase64Jit.Create(b64mSsse3) end), MeasureCreateMs(function: TObject begin Result := TBase64Jit.Create(b64mAuto) end)]));
  Data := MakeData(8388608, 97);
  Scalar := TBase64Jit.Create(b64mScalar);
  Ssse3 := nil;
  if TCpuFeatures.Supports(cfSSSE3) then Ssse3 := TBase64Jit.Create(b64mSsse3);
  Auto := TBase64Jit.Create(b64mAuto);
  Writeln('active auto=', Base64ModeText(Auto.Mode));
  try
    if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickSizes) else Count := Length(FullSizes);
    for K := 0 to Count - 1 do
    begin
      if SameText(GConfig.ModeName, 'quick') then Size := QuickSizes[K] else Size := FullSizes[K];
      BenchMode('Base64 scalar', Scalar, Size, E0, D0);
      if Ssse3 <> nil then
      begin
        BenchMode('Base64 SSSE3', Ssse3, Size, E1, D1);
        PrintSpeedup('SSSE3 encode', E0, E1);
        PrintSpeedup('SSSE3 decode', D0, D1);
      end;
      BenchMode('Base64 auto', Auto, Size, EA, DA);
      PrintSpeedup('auto encode', E0, EA);
      PrintSpeedup('auto decode', D0, DA);
    end;
  finally
    Auto.Free;
    Ssse3.Free;
    Scalar.Free;
  end;
end;

procedure RunHex;
const
  FullSizes: array[0..3] of Integer = (64, 4096, 1048576, 8388608);
  QuickSizes: array[0..1] of Integer = (4096, 1048576);
var
  Data, Encoded, Decoded: TBytes;
  Scalar, Ssse3, Auto: THexJit;
  Size, EncSize, K, Count: Integer;
  InvalidIndex: NativeInt;

  procedure PrepareEncoded(Jit: THexJit; N: Integer);
  begin
    EncSize := N * 2;
    SetLength(Encoded, EncSize);
    SetLength(Decoded, N);
    Jit.Encode(@Data[0], N, @Encoded[0]);
  end;

  procedure BenchMode(const Prefix: string; Jit: THexJit; N: Integer; out RE, RD: TBenchResult);
  begin
    PrepareEncoded(Jit, N);
    RE := RunBenchmark('Hex', Prefix + ' encode ' + FormatBytes(N), 'byte', N, tkBytes,
      procedure(Iterations: Int64)
      var I: Int64;
      begin
        for I := 1 to Iterations do Jit.Encode(@Data[0], N, @Encoded[0]);
        Sink(UInt64(Encoded[0]) xor (UInt64(Encoded[EncSize - 1]) shl 8));
      end);
    RD := RunBenchmark('Hex', Prefix + ' decode ' + FormatBytes(N), 'byte', N, tkBytes,
      procedure(Iterations: Int64)
      var I: Int64; Ok: Boolean;
      begin
        Ok := False;
        for I := 1 to Iterations do Ok := Jit.TryDecode(@Encoded[0], EncSize, @Decoded[0], InvalidIndex);
        if not Ok then raise Exception.Create('Hex benchmark decode failed');
        Sink(UInt64(Decoded[0]) xor (UInt64(Decoded[N - 1]) shl 8));
      end);
  end;

var
  E0, D0, E1, D1, EA, DA: TBenchResult;
begin
  PrintSection('Hex');
  Writeln(Format('setup scalar=%.3f ms  ssse3=%s  auto=%.3f ms', [MeasureCreateMs(function: TObject begin Result := THexJit.Create(hmScalar) end), OptionalSetup(TCpuFeatures.Supports(cfSSSE3), function: TObject begin Result := THexJit.Create(hmSsse3) end), MeasureCreateMs(function: TObject begin Result := THexJit.Create(hmAuto) end)]));
  Data := MakeData(8388608, 101);
  Scalar := THexJit.Create(hmScalar);
  Ssse3 := nil;
  if TCpuFeatures.Supports(cfSSSE3) then Ssse3 := THexJit.Create(hmSsse3);
  Auto := THexJit.Create(hmAuto);
  Writeln('active auto=', HexModeText(Auto.Mode));
  try
    if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickSizes) else Count := Length(FullSizes);
    for K := 0 to Count - 1 do
    begin
      if SameText(GConfig.ModeName, 'quick') then Size := QuickSizes[K] else Size := FullSizes[K];
      BenchMode('Hex scalar', Scalar, Size, E0, D0);
      if Ssse3 <> nil then
      begin
        BenchMode('Hex SSSE3', Ssse3, Size, E1, D1);
        PrintSpeedup('SSSE3 encode', E0, E1);
        PrintSpeedup('SSSE3 decode', D0, D1);
      end;
      BenchMode('Hex auto', Auto, Size, EA, DA);
      PrintSpeedup('auto encode', E0, EA);
      PrintSpeedup('auto decode', D0, DA);
    end;
  finally
    Auto.Free;
    Ssse3.Free;
    Scalar.Free;
  end;
end;

procedure RunBloom;
const
  ItemSize = 16;
var
  Filter: TBloomFilter;
  Data, MissData: TBytes;
  ItemCount, I: Integer;
begin
  PrintSection('Bloom filter');
  if SameText(GConfig.ModeName, 'quick') then ItemCount := 4096 else ItemCount := 65536;
  Data := MakeData(ItemCount * ItemSize, 701);
  MissData := MakeData(ItemCount * ItemSize, 907);
  Filter := TBloomFilter.Create(1 shl 23, 7);
  try
    RunBenchmark('Bloom filter', 'Bloom add batch', 'item', ItemCount, tkOperations,
      procedure(Iterations: Int64)
      var N: Int64; K: Integer;
      begin
        for N := 1 to Iterations do
          for K := 0 to ItemCount - 1 do Filter.Add(@Data[K * ItemSize], ItemSize);
        Sink(UInt64(Filter.BitCount));
      end);
    for I := 0 to ItemCount - 1 do Filter.Add(@Data[I * ItemSize], ItemSize);
    RunBenchmark('Bloom filter', 'Bloom contains hit batch', 'item', ItemCount, tkOperations,
      procedure(Iterations: Int64)
      var N, Hits: Int64; K: Integer;
      begin
        Hits := 0;
        for N := 1 to Iterations do
          for K := 0 to ItemCount - 1 do if Filter.Contains(@Data[K * ItemSize], ItemSize) then Inc(Hits);
        Sink(UInt64(Hits));
      end);
    RunBenchmark('Bloom filter', 'Bloom contains miss batch', 'item', ItemCount, tkOperations,
      procedure(Iterations: Int64)
      var N, Hits: Int64; K: Integer;
      begin
        Hits := 0;
        for N := 1 to Iterations do
          for K := 0 to ItemCount - 1 do if Filter.Contains(@MissData[K * ItemSize], ItemSize) then Inc(Hits);
        Sink(UInt64(Hits));
      end);
  finally
    Filter.Free;
  end;
end;

procedure RunPrng;
const
  FullSizes: array[0..1] of Integer = (1048576, 8388608);
  QuickSizes: array[0..0] of Integer = (1048576);
var
  Output: TBytes;
  Scalar: TXoshiro256ppJit;
  Parallel: TXoshiro256ppParallelJit;
  State: TXoshiro256ppState;
  PState: TXoshiro256ppParallelState;
  Size, K, Count: Integer;
begin
  PrintSection('xoshiro256++');
  Writeln(Format('setup scalar=%.3f ms  parallel=%s', [MeasureCreateMs(function: TObject begin Result := TXoshiro256ppJit.Create end), OptionalSetup(TCpuFeatures.Supports(cfSSE2), function: TObject begin Result := TXoshiro256ppParallelJit.Create end)]));
  SetLength(Output, 8388608);
  Scalar := TXoshiro256ppJit.Create;
  Parallel := nil;
  if TCpuFeatures.Supports(cfSSE2) then Parallel := TXoshiro256ppParallelJit.Create;
  try
    if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickSizes) else Count := Length(FullSizes);
    for K := 0 to Count - 1 do
    begin
      if SameText(GConfig.ModeName, 'quick') then Size := QuickSizes[K] else Size := FullSizes[K];
      TXoshiro256ppJit.SeedState(State, UInt64($123456789ABCDEF0));
      RunBenchmark('xoshiro256++', 'xoshiro256++ scalar fill ' + FormatBytes(Size), 'byte', Size, tkBytes,
        procedure(Iterations: Int64)
        var N: Int64;
        begin
          for N := 1 to Iterations do Scalar.Fill(State, @Output[0], Size div 8);
          Sink(UInt64(Output[0]) xor (UInt64(Output[Size - 1]) shl 8));
        end);
      if Parallel <> nil then
      begin
        TXoshiro256ppParallelJit.SeedState(PState, UInt64($123456789ABCDEF0));
        RunBenchmark('xoshiro256++', 'xoshiro256++ SSE2 2-stream ' + FormatBytes(Size), 'byte', Size, tkBytes,
          procedure(Iterations: Int64)
          var N: Int64;
          begin
            for N := 1 to Iterations do Parallel.FillInterleaved(PState, @Output[0], Size div 16);
            Sink(UInt64(Output[0]) xor (UInt64(Output[Size - 1]) shl 8));
          end);
      end;
    end;
  finally
    Parallel.Free;
    Scalar.Free;
  end;
end;


function MakeBigLimbs(Limbs: Integer; Seed: UInt64): TBigIntLimbs;
var
  I: Integer;
begin
  SetLength(Result, Limbs);
  for I := 0 to Limbs - 1 do
  begin
    Seed := Seed xor (Seed shl 13);
    Seed := Seed xor (Seed shr 7);
    Seed := Seed xor (Seed shl 17);
    Result[I] := Seed;
  end;
end;

function FixedWidthName(Limbs: Integer): string;
begin
  Result := IntToStr(Limbs * 64) + '-bit';
end;

procedure MakeCanonicalPair(const N: TBigIntLimbs; out A, B: TBigIntLimbs);
var
  S: TBigIntLimbs;
  L: Integer;
begin
  L := Length(N);
  SetLength(A, L); SetLength(B, L); SetLength(S, L);
  Move(N[0], A[0], L * SizeOf(UInt64)); Move(N[0], B[0], L * SizeOf(UInt64));
  S[0] := $12345; TBigIntCore.Sub(@A[0], @A[0], @S[0], L);
  FillChar(S[0], L * SizeOf(UInt64), 0); S[0] := $FEDCB; TBigIntCore.Sub(@B[0], @B[0], @S[0], L);
end;

function MakeRsaModulus(Limbs: Integer; Seed: UInt64): TBigIntLimbs;
begin
  Result := MakeBigLimbs(Limbs, Seed);
  Result[0] := Result[0] or 1;
  Result[Limbs - 1] := Result[Limbs - 1] or UInt64($8000000000000000);
end;

procedure RunBigIntCore;
const
  FullWidths: array[0..7] of Integer = (4, 6, 7, 8, 9, 32, 48, 64);
  QuickWidths: array[0..2] of Integer = (4, 9, 32);
var
  A, B, R, W: TBigIntLimbs;
  J: TBigIntJit;
  N, K, Count: Integer;
  Carry: UInt64;
begin
  PrintSection('BigInt fixed-width JIT');
  if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickWidths) else Count := Length(FullWidths);
  for K := 0 to Count - 1 do
  begin
    if SameText(GConfig.ModeName, 'quick') then N := QuickWidths[K] else N := FullWidths[K];
    A := MakeBigLimbs(N, UInt64($123456789ABCDEF0) xor UInt64(N));
    B := MakeBigLimbs(N, UInt64($0FEDCBA987654321) xor UInt64(N shl 8));
    SetLength(R, N); SetLength(W, N * 2);
    Writeln(Format('setup %-8s %.3f ms', [FixedWidthName(N), MeasureCreateMs(function: TObject begin Result := TBigIntJit.Create(N) end)]));
    J := TBigIntJit.Create(N);
    try
      RunBenchmark('BigInt fixed-width JIT', 'BigInt add ' + FixedWidthName(N), 'op', 1, tkOperations,
        procedure(Iterations: Int64)
        var I: Int64;
        begin
          Carry := 0;
          for I := 1 to Iterations do Carry := Carry xor J.Add(@R[0], @A[0], @B[0]);
          Sink(R[0] xor R[N - 1] xor Carry);
        end);
      RunBenchmark('BigInt fixed-width JIT', 'BigInt sub ' + FixedWidthName(N), 'op', 1, tkOperations,
        procedure(Iterations: Int64)
        var I: Int64;
        begin
          Carry := 0;
          for I := 1 to Iterations do Carry := Carry xor J.Sub(@R[0], @A[0], @B[0]);
          Sink(R[0] xor R[N - 1] xor Carry);
        end);
      RunBenchmark('BigInt fixed-width JIT', 'BigInt mulwide ' + FixedWidthName(N), 'op', 1, tkOperations,
        procedure(Iterations: Int64)
        var I: Int64;
        begin
          for I := 1 to Iterations do J.MulWide(@W[0], @A[0], @B[0]);
          Sink(W[0] xor W[N * 2 - 1]);
        end);
      if N <= 9 then
        RunBenchmark('BigInt fixed-width JIT', 'BigInt square ' + FixedWidthName(N), 'op', 1, tkOperations,
          procedure(Iterations: Int64)
          var I: Int64;
          begin
            for I := 1 to Iterations do J.SquareWide(@W[0], @A[0]);
            Sink(W[0] xor W[N * 2 - 1]);
          end);
    finally
      J.Free;
    end;
  end;
end;

procedure RunBigIntFields;
const
  FullFields: array[0..5] of TPrimeFieldId = (pfSecp256k1, pfP256, pfP384, pfCurve25519, pfCurve448, pfP521);
  QuickFields: array[0..2] of TPrimeFieldId = (pfSecp256k1, pfCurve448, pfP521);
var
  Id: TPrimeFieldId;
  N, A, B, AM, BM, R: TBigIntLimbs;
  C: TMontgomeryContext;
  K, Count, L: Integer;
  Name: string;

  function FieldName(Value: TPrimeFieldId): string;
  begin
    case Value of
      pfSecp256k1: Result := 'secp256k1';
      pfP256: Result := 'P-256';
      pfP384: Result := 'P-384';
      pfP521: Result := 'P-521';
      pfCurve25519: Result := 'Curve25519';
      pfCurve448: Result := 'Curve448';
    else
      Result := 'field';
    end;
  end;

begin
  PrintSection('BigInt Montgomery fields');
  if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickFields) else Count := Length(FullFields);
  for K := 0 to Count - 1 do
  begin
    if SameText(GConfig.ModeName, 'quick') then Id := QuickFields[K] else Id := FullFields[K];
    N := TPrimeFieldFactory.Modulus(Id); L := Length(N); Name := FieldName(Id);
    MakeCanonicalPair(N, A, B); SetLength(AM, L); SetLength(BM, L); SetLength(R, L);
    Writeln(Format('setup %-12s %.3f ms', [Name, MeasureCreateMs(function: TObject begin Result := TMontgomeryContext.Create(N) end)]));
    C := TMontgomeryContext.Create(N);
    try
      C.Encode(@AM[0], @A[0]); C.Encode(@BM[0], @B[0]);
      RunBenchmark('BigInt Montgomery fields', 'MontMul ' + Name, 'op', 1, tkOperations,
        procedure(Iterations: Int64)
        var I: Int64;
        begin
          for I := 1 to Iterations do C.MontMul(@R[0], @AM[0], @BM[0]);
          Sink(R[0] xor R[L - 1]);
        end);
      RunBenchmark('BigInt Montgomery fields', 'MontSquare ' + Name, 'op', 1, tkOperations,
        procedure(Iterations: Int64)
        var I: Int64;
        begin
          for I := 1 to Iterations do C.MontSquare(@R[0], @AM[0]);
          Sink(R[0] xor R[L - 1]);
        end);
    finally
      C.Free;
    end;
  end;
end;

procedure RunBigIntRsa;
const
  FullWidths: array[0..2] of Integer = (32, 48, 64);
  QuickWidths: array[0..0] of Integer = (32);
var
  N, A, B, AM, BM, R: TBigIntLimbs;
  C: TMontgomeryContext;
  Exp65537: array[0..2] of Byte;
  L, K, Count: Integer;
  Name: string;
begin
  PrintSection('BigInt RSA-size Montgomery');
  Exp65537[0] := 1; Exp65537[1] := 0; Exp65537[2] := 1;
  if SameText(GConfig.ModeName, 'quick') then Count := Length(QuickWidths) else Count := Length(FullWidths);
  for K := 0 to Count - 1 do
  begin
    if SameText(GConfig.ModeName, 'quick') then L := QuickWidths[K] else L := FullWidths[K];
    Name := IntToStr(L * 64) + '-bit';
    N := MakeRsaModulus(L, UInt64($D1B54A32D192ED03) xor UInt64(L)); MakeCanonicalPair(N, A, B);
    SetLength(AM, L); SetLength(BM, L); SetLength(R, L);
    Writeln(Format('setup RSA %-8s %.3f ms', [Name, MeasureCreateMs(function: TObject begin Result := TMontgomeryContext.Create(N) end)]));
    C := TMontgomeryContext.Create(N);
    try
      C.Encode(@AM[0], @A[0]); C.Encode(@BM[0], @B[0]);
      RunBenchmark('BigInt RSA-size Montgomery', 'RSA-size MontMul ' + Name, 'op', 1, tkOperations,
        procedure(Iterations: Int64)
        var I: Int64;
        begin
          for I := 1 to Iterations do C.MontMul(@R[0], @AM[0], @BM[0]);
          Sink(R[0] xor R[L - 1]);
        end);
      RunBenchmark('BigInt RSA-size Montgomery', 'RSA-size MontSquare ' + Name, 'op', 1, tkOperations,
        procedure(Iterations: Int64)
        var I: Int64;
        begin
          for I := 1 to Iterations do C.MontSquare(@R[0], @AM[0]);
          Sink(R[0] xor R[L - 1]);
        end);
      RunBenchmark('BigInt RSA-size Montgomery', 'RSA public pow e=65537 ' + Name, 'op', 1, tkOperations,
        procedure(Iterations: Int64)
        var I: Int64;
        begin
          for I := 1 to Iterations do C.PowVar(@R[0], @A[0], @Exp65537[0], Length(Exp65537));
          Sink(R[0] xor R[L - 1]);
        end);
    finally
      C.Free;
    end;
  end;
end;

procedure RunAllBenchmarks;
begin
  if GroupEnabled('crc') then begin RunCrc32; RunCrc32C; end;
  if GroupEnabled('hash') then begin RunHash64; RunBlake3; end;
  if GroupEnabled('crypto') then begin RunChaCha20; RunPoly1305; RunAead; end;
  if GroupEnabled('codec') then begin RunBase64; RunHex; end;
  if GroupEnabled('bloom') then RunBloom;
  if GroupEnabled('prng') then RunPrng;
  if GroupEnabled('bigint') then begin RunBigIntCore; RunBigIntFields; RunBigIntRsa; end;
end;

end.

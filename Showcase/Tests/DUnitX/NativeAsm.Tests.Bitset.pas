{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Bitset;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.CpuFeatures,
  NativeAsm.Algorithms.Bitset;

type
  TUInt64Array = array of UInt64;

  [TestFixture]
  TBitsetTests = class
  private
    class function MakeWords(Count: Integer; Salt: UInt64): TUInt64Array; static;
    class function ReferencePopCount(const A: TUInt64Array): UInt64; static;
    procedure CheckLogic(Mode: TBitsetLogicMode);
    procedure CheckCount(Mode: TBitsetCountMode);
    procedure CheckScan(Mode: TBitsetScanMode);
  public
    [Test] procedure ScalarLogicMatchesReference;
    [Test] procedure Sse2LogicMatchesReferenceWhenAvailable;
    [Test] procedure ScalarCountMatchesReference;
    [Test] procedure PopcntMatchesReferenceWhenAvailable;
    [Test] procedure BsfScanFindsExpectedBits;
    [Test] procedure TzcntScanFindsExpectedBitsWhenAvailable;
    [Test] procedure AutoModesSelectAvailableFeatures;
    [Test] procedure ZeroLengthAcceptsNil;
    [Test] procedure NonZeroLengthRejectsNil;
  end;

implementation

class function TBitsetTests.MakeWords(Count: Integer; Salt: UInt64): TUInt64Array;
var
  I: Integer;
begin
  SetLength(Result, Count);
  for I := 0 to High(Result) do Result[I] := (UInt64(I + 1) * UInt64($9E3779B97F4A7C15)) xor (Salt + UInt64(I) * UInt64($0101010101010101));
end;

class function TBitsetTests.ReferencePopCount(const A: TUInt64Array): UInt64;
var
  I: Integer;
  V: UInt64;
begin
  Result := 0;
  for I := 0 to High(A) do
  begin
    V := A[I];
    while V <> 0 do
    begin
      V := V and (V - 1);
      Inc(Result);
    end;
  end;
end;

procedure TBitsetTests.CheckLogic(Mode: TBitsetLogicMode);
var
  Jit: TBitsetJit;
  A, B, D: TUInt64Array;
  I: Integer;
begin
  A := MakeWords(7, $123456789ABCDEF0);
  B := MakeWords(7, $0F1E2D3C4B5A6978);
  SetLength(D, Length(A));
  Jit := TBitsetJit.Create(Mode, bcmScalar, bsmBsf);
  try
    Jit.AndBits(@D[0], @A[0], @B[0], NativeUInt(Length(A)));
    for I := 0 to High(A) do Assert.IsTrue(D[I] = (A[I] and B[I]), 'AND ' + IntToStr(I));
    Jit.OrBits(@D[0], @A[0], @B[0], NativeUInt(Length(A)));
    for I := 0 to High(A) do Assert.IsTrue(D[I] = (A[I] or B[I]), 'OR ' + IntToStr(I));
    Jit.XorBits(@D[0], @A[0], @B[0], NativeUInt(Length(A)));
    for I := 0 to High(A) do Assert.IsTrue(D[I] = (A[I] xor B[I]), 'XOR ' + IntToStr(I));
    Jit.Invert(@D[0], @A[0], NativeUInt(Length(A)));
    for I := 0 to High(A) do Assert.IsTrue(D[I] = not A[I], 'NOT ' + IntToStr(I));
    for I := 0 to High(D) do D[I] := A[I];
    Jit.XorBits(@D[0], @D[0], @B[0], NativeUInt(Length(D)));
    for I := 0 to High(D) do Assert.IsTrue(D[I] = (A[I] xor B[I]), 'in-place XOR ' + IntToStr(I));
  finally
    Jit.Free;
  end;
end;

procedure TBitsetTests.CheckCount(Mode: TBitsetCountMode);
var
  Jit: TBitsetJit;
  A: TUInt64Array;
  Expected: UInt64;
begin
  A := MakeWords(33, $A55AA55A01234567);
  A[0] := 0;
  A[1] := High(UInt64);
  A[2] := UInt64(1) shl 63;
  Expected := ReferencePopCount(A);
  Jit := TBitsetJit.Create(blmScalar, Mode, bsmBsf);
  try
    Assert.IsTrue(Jit.PopCount(@A[0], NativeUInt(Length(A))) = Expected);
  finally
    Jit.Free;
  end;
end;

procedure TBitsetTests.CheckScan(Mode: TBitsetScanMode);
var
  Jit: TBitsetJit;
  A: array[0..3] of UInt64;
begin
  FillChar(A, SizeOf(A), 0);
  A[0] := (UInt64(1) shl 3) or (UInt64(1) shl 63);
  A[1] := UInt64(1) shl 0;
  A[2] := UInt64(1) shl 17;
  A[3] := UInt64(1) shl 63;
  Jit := TBitsetJit.Create(blmScalar, bcmScalar, Mode);
  try
    Assert.IsTrue(Jit.FindFirstSet(@A[0], 4) = 3);
    Assert.IsTrue(Jit.FindNextSet(@A[0], 4, 0) = 3);
    Assert.IsTrue(Jit.FindNextSet(@A[0], 4, 3) = 3);
    Assert.IsTrue(Jit.FindNextSet(@A[0], 4, 4) = 63);
    Assert.IsTrue(Jit.FindNextSet(@A[0], 4, 64) = 64);
    Assert.IsTrue(Jit.FindNextSet(@A[0], 4, 65) = 145);
    Assert.IsTrue(Jit.FindNextSet(@A[0], 4, 146) = 255);
    Assert.IsTrue(Jit.FindNextSet(@A[0], 4, 256) = -1);
    Assert.IsTrue(Jit.FindNextSet(@A[0], 4, High(NativeUInt)) = -1);
  finally
    Jit.Free;
  end;
end;

procedure TBitsetTests.ScalarLogicMatchesReference;
begin
  CheckLogic(blmScalar);
end;

procedure TBitsetTests.Sse2LogicMatchesReferenceWhenAvailable;
begin
  if TCpuFeatures.Supports(cfSSE2) then CheckLogic(blmSse2) else Assert.IsTrue(True);
end;

procedure TBitsetTests.ScalarCountMatchesReference;
begin
  CheckCount(bcmScalar);
end;

procedure TBitsetTests.PopcntMatchesReferenceWhenAvailable;
begin
  if TCpuFeatures.Supports(cfPOPCNT) then CheckCount(bcmPopcnt) else Assert.IsTrue(True);
end;

procedure TBitsetTests.BsfScanFindsExpectedBits;
begin
  CheckScan(bsmBsf);
end;

procedure TBitsetTests.TzcntScanFindsExpectedBitsWhenAvailable;
begin
  if TCpuFeatures.Supports(cfBMI1) then CheckScan(bsmTzcnt) else Assert.IsTrue(True);
end;

procedure TBitsetTests.AutoModesSelectAvailableFeatures;
var
  Jit: TBitsetJit;
begin
  Jit := TBitsetJit.Create;
  try
    if TCpuFeatures.Supports(cfSSE2) then Assert.IsTrue(Jit.LogicMode = blmSse2) else Assert.IsTrue(Jit.LogicMode = blmScalar);
    if TCpuFeatures.Supports(cfPOPCNT) then Assert.IsTrue(Jit.CountMode = bcmPopcnt) else Assert.IsTrue(Jit.CountMode = bcmScalar);
    if TCpuFeatures.Supports(cfBMI1) then Assert.IsTrue(Jit.ScanMode = bsmTzcnt) else Assert.IsTrue(Jit.ScanMode = bsmBsf);
  finally
    Jit.Free;
  end;
end;

procedure TBitsetTests.ZeroLengthAcceptsNil;
var
  Jit: TBitsetJit;
begin
  Jit := TBitsetJit.Create(blmScalar, bcmScalar, bsmBsf);
  try
    Jit.AndBits(nil, nil, nil, 0);
    Jit.OrBits(nil, nil, nil, 0);
    Jit.XorBits(nil, nil, nil, 0);
    Jit.Invert(nil, nil, 0);
    Assert.IsTrue(Jit.PopCount(nil, 0) = 0);
    Assert.IsTrue(Jit.FindFirstSet(nil, 0) = -1);
  finally
    Jit.Free;
  end;
end;

procedure TBitsetTests.NonZeroLengthRejectsNil;
var
  Jit: TBitsetJit;
  Raised: Boolean;
begin
  Jit := TBitsetJit.Create(blmScalar, bcmScalar, bsmBsf);
  try
    Raised := False;
    try
      Jit.PopCount(nil, 1);
    except
      on E: EArgumentNilException do Raised := True;
    end;
    Assert.IsTrue(Raised);
  finally
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBitsetTests);

end.
